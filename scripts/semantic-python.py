#!/usr/bin/env python3

from __future__ import annotations

import argparse
import io
import json
import keyword
import tokenize
from dataclasses import dataclass
from pathlib import Path


Operation = str


@dataclass(frozen=True)
class TokenEdit:
    start_line: int
    start_col: int
    end_line: int
    end_col: int


@dataclass(frozen=True)
class TokenLocation:
    file: Path
    start_line: int
    start_col: int
    end_line: int
    end_col: int
    is_attribute: bool


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Deterministic Python semantic backend for SBK."
    )
    parser.add_argument(
        "--operation",
        default="rename",
        choices=["rename", "reference-map", "safe-delete-candidates"],
    )
    parser.add_argument("--file", required=True)
    parser.add_argument("--line", required=True, type=int)
    parser.add_argument("--column", required=True, type=int)
    parser.add_argument("--newName")
    parser.add_argument("--targetRepoRoot", default=".")
    parser.add_argument("--dryRun", action="store_true")
    parser.add_argument("--maxResults", default=200, type=int)
    return parser.parse_args()


def validate_new_name(new_name: str) -> None:
    if not new_name.isidentifier():
        raise ValueError(f"newName '{new_name}' is not a valid Python identifier")
    if keyword.iskeyword(new_name):
        raise ValueError(f"newName '{new_name}' cannot be a Python keyword")


def line_col_to_offset(content: str, line: int, col: int) -> int:
    if line <= 0 or col < 0:
        raise ValueError("line/column must be positive values")
    lines = content.splitlines(keepends=True)
    if line > len(lines):
        raise ValueError(f"line {line} exceeds file line count {len(lines)}")
    line_text = lines[line - 1]
    if col > len(line_text):
        raise ValueError(f"column {col} exceeds line length {len(line_text)}")
    return sum(len(lines[i]) for i in range(line - 1)) + col


def offset_to_line_col(content: str, offset: int) -> tuple[int, int]:
    if offset < 0:
        return (1, 1)
    line = 1
    col = 1
    limit = min(offset, len(content))
    for idx in range(limit):
        if content[idx] == "\n":
            line += 1
            col = 1
        else:
            col += 1
    return (line, col)


def tokenize_file(path: Path) -> list[tokenize.TokenInfo]:
    content = path.read_text(encoding="utf8")
    return list(tokenize.generate_tokens(io.StringIO(content).readline))


def pick_symbol(tokens: list[tokenize.TokenInfo], line: int, column_1_based: int) -> str:
    column = max(0, column_1_based - 1)
    for token in tokens:
        if token.type != tokenize.NAME:
            continue
        start_line, start_col = token.start
        end_line, end_col = token.end
        if start_line != line:
            continue
        if start_col <= column < end_col:
            return token.string
    raise ValueError(
        "unable to resolve Python symbol at target location; place cursor on an identifier"
    )


def is_attribute_leaf(tokens: list[tokenize.TokenInfo], index: int) -> bool:
    probe = index - 1
    while probe >= 0:
        candidate = tokens[probe]
        if candidate.type in (
            tokenize.INDENT,
            tokenize.DEDENT,
            tokenize.NL,
            tokenize.NEWLINE,
            tokenize.COMMENT,
            tokenize.ENCODING,
            tokenize.ENDMARKER,
        ):
            probe -= 1
            continue
        return candidate.string == "."
    return False


def collect_locations(
    tokens: list[tokenize.TokenInfo], symbol: str, file: Path
) -> list[TokenLocation]:
    locations: list[TokenLocation] = []
    for index, token in enumerate(tokens):
        if token.type != tokenize.NAME or token.string != symbol:
            continue
        locations.append(
            TokenLocation(
                file=file,
                start_line=token.start[0],
                start_col=token.start[1],
                end_line=token.end[0],
                end_col=token.end[1],
                is_attribute=is_attribute_leaf(tokens, index),
            )
        )
    return locations


def iter_python_files(root: Path) -> list[Path]:
    ignore_dirs = {
        ".git",
        "node_modules",
        ".venv",
        ".mypy_cache",
        ".pytest_cache",
        ".metrics",
        ".trellis",
        ".codex",
        ".agents",
        ".claude",
        "dist",
        "build",
        "target",
    }
    files: list[Path] = []
    for candidate in root.rglob("*.py"):
        if any(part in ignore_dirs for part in candidate.parts):
            continue
        files.append(candidate)
    files.sort(key=lambda item: str(item))
    return files


def collect_project_locations(root: Path, symbol: str) -> list[TokenLocation]:
    all_locations: list[TokenLocation] = []
    for file in iter_python_files(root):
        try:
            tokens = tokenize_file(file)
        except Exception:
            continue
        all_locations.extend(collect_locations(tokens, symbol, file))
    return all_locations


def apply_edits(content: str, edits: list[TokenEdit], replacement: str) -> str:
    prepared = []
    for edit in edits:
        start = line_col_to_offset(content, edit.start_line, edit.start_col)
        end = line_col_to_offset(content, edit.end_line, edit.end_col)
        prepared.append((start, end))
    prepared.sort(key=lambda item: item[0], reverse=True)

    next_content = content
    for start, end in prepared:
        next_content = next_content[:start] + replacement + next_content[end:]
    return next_content


def rewrite_locations(
    locations: list[TokenLocation], replacement: str, dry_run: bool
) -> tuple[int, int]:
    by_file: dict[Path, list[TokenEdit]] = {}
    for loc in locations:
        if loc.is_attribute:
            continue
        by_file.setdefault(loc.file, []).append(
            TokenEdit(
                start_line=loc.start_line,
                start_col=loc.start_col,
                end_line=loc.end_line,
                end_col=loc.end_col,
            )
        )

    touched_files = 0
    touched_locations = 0
    for file, edits in by_file.items():
        touched_files += 1
        touched_locations += len(edits)
        if dry_run:
            continue
        content = file.read_text(encoding="utf8")
        updated = apply_edits(content, edits, replacement)
        file.write_text(updated, encoding="utf8")
    return (touched_files, touched_locations)


def to_reference_payload(
    operation: Operation,
    symbol: str,
    target_file: Path,
    line: int,
    column: int,
    locations: list[TokenLocation],
    max_results: int,
    repo_root: Path,
) -> dict:
    emitted = locations[:max_results]
    touched_files = {str(loc.file.resolve()) for loc in locations}
    return {
        "operation": operation,
        "mode": "analysis",
        "backend": "python-token-index",
        "symbol": symbol,
        "from": {
            "file": str(target_file.resolve()),
            "line": line,
            "column": column,
        },
        "summary": {
            "totalReferences": len(locations),
            "emittedReferences": len(emitted),
            "truncated": len(locations) > len(emitted),
            "touchedFiles": len(touched_files),
            "attributeReferences": sum(1 for loc in locations if loc.is_attribute),
            "repoRoot": str(repo_root.resolve()),
        },
        "references": [
            {
                "file": str(loc.file.resolve()),
                "line": loc.start_line,
                "column": loc.start_col + 1,
                "isAttribute": loc.is_attribute,
            }
            for loc in emitted
        ],
    }


def build_safe_delete_payload(
    symbol: str,
    target_file: Path,
    line: int,
    column: int,
    locations: list[TokenLocation],
    max_results: int,
    repo_root: Path,
) -> dict:
    non_attribute = [loc for loc in locations if not loc.is_attribute]
    safe_to_delete = len(non_attribute) <= 1
    confidence = "high" if safe_to_delete else ("medium" if len(non_attribute) <= 3 else "low")
    payload = to_reference_payload(
        "safe-delete-candidates",
        symbol,
        target_file,
        line,
        column,
        locations,
        max_results,
        repo_root,
    )
    payload["candidate"] = {
        "safeToDelete": safe_to_delete,
        "confidence": confidence,
        "nonAttributeReferences": len(non_attribute),
        "rationale": (
            "symbol appears once (or only as attribute usage)"
            if safe_to_delete
            else "symbol has multiple non-attribute references"
        ),
    }
    return payload


def main() -> None:
    args = parse_args()
    if args.maxResults <= 0:
        raise ValueError("maxResults must be a positive integer")

    operation = args.operation
    if operation == "rename" and not args.newName:
        raise ValueError("rename operation requires --newName")
    if operation == "rename":
        validate_new_name(args.newName)

    target = Path(args.file)
    if not target.exists():
        raise ValueError(f"file not found: {target}")

    repo_root = Path(args.targetRepoRoot)
    if not repo_root.exists():
        raise ValueError(f"targetRepoRoot does not exist: {repo_root}")

    content = target.read_text(encoding="utf8")
    token_stream = list(tokenize.generate_tokens(io.StringIO(content).readline))
    symbol = pick_symbol(token_stream, args.line, args.column)
    locations = collect_project_locations(repo_root, symbol)
    if not locations:
        raise ValueError("no references found for selected symbol")

    if operation == "rename":
        touched_files, touched_locations = rewrite_locations(
            locations, args.newName, args.dryRun
        )
        payload = {
            "operation": "rename",
            "mode": "dry-run" if args.dryRun else "apply",
            "backend": "python-token-index",
            "symbol": symbol,
            "to": args.newName,
            "from": {
                "file": str(target.resolve()),
                "line": args.line,
                "column": args.column,
            },
            "touchedFiles": touched_files,
            "touchedLocations": touched_locations,
            "summary": {
                "projectReferences": len(locations),
                "attributeReferences": sum(1 for loc in locations if loc.is_attribute),
            },
        }
        print(json.dumps(payload, indent=2))
        return

    if operation == "reference-map":
        payload = to_reference_payload(
            operation,
            symbol,
            target,
            args.line,
            args.column,
            locations,
            args.maxResults,
            repo_root,
        )
        print(json.dumps(payload, indent=2))
        return

    if operation == "safe-delete-candidates":
        payload = build_safe_delete_payload(
            symbol,
            target,
            args.line,
            args.column,
            locations,
            args.maxResults,
            repo_root,
        )
        print(json.dumps(payload, indent=2))
        return

    raise ValueError(f"unsupported operation: {operation}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001
        print(f"[semantic-python] {exc}")
        raise SystemExit(1) from exc
