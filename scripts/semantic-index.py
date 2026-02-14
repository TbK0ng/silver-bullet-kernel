#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path


OP_RENAME = "rename"
OP_REFERENCE = "reference-map"
OP_SAFE_DELETE = "safe-delete-candidates"

LANGUAGE_EXTENSIONS = {
    "go": [".go"],
    "java": [".java"],
    "rust": [".rs"],
}

IGNORE_PARTS = {
    ".git",
    "node_modules",
    ".venv",
    ".metrics",
    ".trellis",
    ".codex",
    ".agents",
    ".claude",
    "dist",
    "build",
    "target",
}

IDENTIFIER_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


@dataclass(frozen=True)
class MatchRef:
    file: Path
    start: int
    end: int
    line: int
    column: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Deterministic symbol-index semantic backend for Go/Java/Rust."
    )
    parser.add_argument(
        "--operation",
        choices=[OP_RENAME, OP_REFERENCE, OP_SAFE_DELETE],
        default=OP_RENAME,
    )
    parser.add_argument("--language", choices=["go", "java", "rust"], required=True)
    parser.add_argument("--file", required=True)
    parser.add_argument("--line", required=True, type=int)
    parser.add_argument("--column", required=True, type=int)
    parser.add_argument("--newName")
    parser.add_argument("--targetRepoRoot", default=".")
    parser.add_argument("--dryRun", action="store_true")
    parser.add_argument("--maxResults", default=200, type=int)
    return parser.parse_args()


def validate_identifier(value: str) -> None:
    if not IDENTIFIER_RE.fullmatch(value):
        raise ValueError(f"identifier '{value}' is invalid")


def line_col_to_offset(content: str, line: int, column_1_based: int) -> int:
    if line <= 0 or column_1_based <= 0:
        raise ValueError("line and column must be positive integers")
    lines = content.splitlines(keepends=True)
    if line > len(lines):
        raise ValueError(f"line {line} exceeds file line count {len(lines)}")
    line_text = lines[line - 1]
    if column_1_based > len(line_text) + 1:
        raise ValueError(
            f"column {column_1_based} exceeds line length {len(line_text) + 1}"
        )
    return sum(len(lines[i]) for i in range(line - 1)) + (column_1_based - 1)


def offset_to_line_col(content: str, offset: int) -> tuple[int, int]:
    line = 1
    col = 1
    limit = min(max(offset, 0), len(content))
    for idx in range(limit):
        if content[idx] == "\n":
            line += 1
            col = 1
        else:
            col += 1
    return (line, col)


def is_word_char(ch: str) -> bool:
    return ch.isalnum() or ch == "_"


def resolve_symbol_at(content: str, offset: int) -> str:
    if len(content) == 0:
        raise ValueError("target file is empty")

    pivot = min(max(offset, 0), len(content) - 1)
    if not is_word_char(content[pivot]):
        if pivot > 0 and is_word_char(content[pivot - 1]):
            pivot -= 1
        else:
            raise ValueError("no identifier found at specified location")

    start = pivot
    end = pivot
    while start > 0 and is_word_char(content[start - 1]):
        start -= 1
    while end < len(content) - 1 and is_word_char(content[end + 1]):
        end += 1

    symbol = content[start : end + 1]
    validate_identifier(symbol)
    return symbol


def iter_language_files(root: Path, language: str) -> list[Path]:
    extensions = LANGUAGE_EXTENSIONS[language]
    files: list[Path] = []
    for ext in extensions:
        for candidate in root.rglob(f"*{ext}"):
            if any(part in IGNORE_PARTS for part in candidate.parts):
                continue
            files.append(candidate)
    files.sort(key=lambda item: str(item))
    return files


def collect_matches(symbol: str, files: list[Path]) -> list[MatchRef]:
    pattern = re.compile(rf"\b{re.escape(symbol)}\b")
    refs: list[MatchRef] = []
    for file in files:
        try:
            content = file.read_text(encoding="utf8")
        except Exception:
            continue
        for match in pattern.finditer(content):
            line, column = offset_to_line_col(content, match.start())
            refs.append(
                MatchRef(
                    file=file,
                    start=match.start(),
                    end=match.end(),
                    line=line,
                    column=column,
                )
            )
    return refs


def rewrite_files(
    refs: list[MatchRef], replacement: str, dry_run: bool
) -> tuple[int, int]:
    by_file: dict[Path, list[MatchRef]] = {}
    for ref in refs:
        by_file.setdefault(ref.file, []).append(ref)

    touched_files = 0
    touched_locations = 0
    for file, file_refs in by_file.items():
        touched_files += 1
        touched_locations += len(file_refs)
        if dry_run:
            continue
        content = file.read_text(encoding="utf8")
        updated = content
        for ref in sorted(file_refs, key=lambda item: item.start, reverse=True):
            updated = updated[: ref.start] + replacement + updated[ref.end :]
        file.write_text(updated, encoding="utf8")
    return (touched_files, touched_locations)


def build_reference_payload(
    operation: str,
    backend: str,
    symbol: str,
    target_file: Path,
    line: int,
    column: int,
    refs: list[MatchRef],
    max_results: int,
    repo_root: Path,
) -> dict:
    emitted = refs[:max_results]
    touched_files = {str(item.file.resolve()) for item in refs}
    return {
        "operation": operation,
        "mode": "analysis",
        "backend": backend,
        "symbol": symbol,
        "from": {
            "file": str(target_file.resolve()),
            "line": line,
            "column": column,
        },
        "summary": {
            "totalReferences": len(refs),
            "emittedReferences": len(emitted),
            "truncated": len(refs) > len(emitted),
            "touchedFiles": len(touched_files),
            "repoRoot": str(repo_root.resolve()),
        },
        "references": [
            {
                "file": str(item.file.resolve()),
                "line": item.line,
                "column": item.column,
            }
            for item in emitted
        ],
    }


def build_safe_delete_payload(base_payload: dict, refs: list[MatchRef]) -> dict:
    safe_to_delete = len(refs) <= 1
    confidence = "high" if safe_to_delete else ("medium" if len(refs) <= 3 else "low")
    payload = dict(base_payload)
    payload["candidate"] = {
        "safeToDelete": safe_to_delete,
        "confidence": confidence,
        "rationale": (
            "symbol has a single occurrence in language index"
            if safe_to_delete
            else "symbol has multiple references in language index"
        ),
    }
    return payload


def main() -> None:
    args = parse_args()
    if args.operation == OP_RENAME and not args.newName:
        raise ValueError("rename requires --newName")
    if args.newName:
        validate_identifier(args.newName)
    if args.maxResults <= 0:
        raise ValueError("maxResults must be a positive integer")

    target = Path(args.file)
    if not target.exists():
        raise ValueError(f"file not found: {target}")

    repo_root = Path(args.targetRepoRoot)
    if not repo_root.exists():
        raise ValueError(f"targetRepoRoot does not exist: {repo_root}")

    content = target.read_text(encoding="utf8")
    offset = line_col_to_offset(content, args.line, args.column)
    symbol = resolve_symbol_at(content, offset)

    files = iter_language_files(repo_root, args.language)
    if len(files) == 0:
        raise ValueError(
            f"no source files found for language '{args.language}' under {repo_root}"
        )

    refs = collect_matches(symbol, files)
    if len(refs) == 0:
        raise ValueError("no references found for selected symbol")

    backend = "symbol-index"

    if args.operation == OP_RENAME:
        touched_files, touched_locations = rewrite_files(refs, args.newName, args.dryRun)
        payload = {
            "operation": OP_RENAME,
            "mode": "dry-run" if args.dryRun else "apply",
            "backend": backend,
            "language": args.language,
            "symbol": symbol,
            "to": args.newName,
            "from": {
                "file": str(target.resolve()),
                "line": args.line,
                "column": args.column,
            },
            "touchedFiles": touched_files,
            "touchedLocations": touched_locations,
        }
        print(json.dumps(payload, indent=2))
        return

    reference_payload = build_reference_payload(
        args.operation,
        backend,
        symbol,
        target,
        args.line,
        args.column,
        refs,
        args.maxResults,
        repo_root,
    )
    if args.operation == OP_REFERENCE:
        print(json.dumps(reference_payload, indent=2))
        return

    safe_payload = build_safe_delete_payload(reference_payload, refs)
    print(json.dumps(safe_payload, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001
        print(f"[semantic-index] {exc}")
        raise SystemExit(1) from exc
