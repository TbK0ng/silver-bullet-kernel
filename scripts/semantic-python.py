#!/usr/bin/env python3

from __future__ import annotations

import argparse
import io
import json
import keyword
import tokenize
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class TokenEdit:
    start_line: int
    start_col: int
    end_line: int
    end_col: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Deterministic Python rename backend for SBK.")
    parser.add_argument("--file", required=True)
    parser.add_argument("--line", required=True, type=int)
    parser.add_argument("--column", required=True, type=int)
    parser.add_argument("--newName", required=True)
    parser.add_argument("--dryRun", action="store_true")
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


def pick_symbol(tokens: list[tokenize.TokenInfo], line: int, column: int) -> str:
    for token in tokens:
        if token.type != tokenize.NAME:
            continue
        start_line, start_col = token.start
        end_line, end_col = token.end
        if start_line != line:
            continue
        if start_col <= column <= end_col:
            return token.string
    raise ValueError(
        "unable to resolve Python symbol at target location; place cursor on an identifier"
    )


def collect_edits(tokens: list[tokenize.TokenInfo], symbol: str) -> list[TokenEdit]:
    edits: list[TokenEdit] = []
    for index, token in enumerate(tokens):
        if token.type != tokenize.NAME or token.string != symbol:
            continue

        prev_non_trivia = None
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
            prev_non_trivia = candidate
            break

        # Keep rename conservative by avoiding attribute leaf rewrite: `obj.symbol`
        if prev_non_trivia is not None and prev_non_trivia.string == ".":
            continue

        edits.append(
            TokenEdit(
                start_line=token.start[0],
                start_col=token.start[1],
                end_line=token.end[0],
                end_col=token.end[1],
            )
        )
    return edits


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


def main() -> None:
    args = parse_args()
    validate_new_name(args.newName)

    target = Path(args.file)
    if not target.exists():
        raise ValueError(f"file not found: {target}")

    content = target.read_text(encoding="utf8")
    token_stream = list(tokenize.generate_tokens(io.StringIO(content).readline))
    symbol = pick_symbol(token_stream, args.line, args.column)
    edits = collect_edits(token_stream, symbol)
    if not edits:
        raise ValueError("no deterministic rename locations found for selected symbol")

    if not args.dryRun:
        next_content = apply_edits(content, edits, args.newName)
        target.write_text(next_content, encoding="utf8")

    payload = {
        "mode": "dry-run" if args.dryRun else "apply",
        "backend": "python-ast-token",
        "symbol": symbol,
        "to": args.newName,
        "from": {
            "file": str(target),
            "line": args.line,
            "column": args.column,
        },
        "touchedFiles": 1,
        "touchedLocations": len(edits),
        "locations": [
            {"line": edit.start_line, "column": edit.start_col + 1} for edit in edits
        ],
    }
    print(json.dumps(payload, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001
        print(f"[semantic-python] {exc}")
        raise SystemExit(1) from exc
