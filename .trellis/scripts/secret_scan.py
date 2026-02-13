#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Secret Scanner - Scan for leaked secrets in codebase.

Integrates with detect-secrets if available, otherwise uses built-in
pattern matching based on policy.yaml configuration.

Usage:
    # Scan staged changes
    python3 secret_scan.py --staged

    # Scan all changed files (compared to base branch)
    python3 secret_scan.py --diff main

    # Scan specific files
    python3 secret_scan.py --files file1.py file2.py

    # Update baseline
    python3 secret_scan.py --update-baseline
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

# Handle Windows encoding
if sys.platform == "win32":
    import io as _io
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")


# =============================================================================
# Data Classes
# =============================================================================

@dataclass
class SecretFinding:
    """A potential secret finding."""
    file: str
    line: int
    type: str
    severity: str
    matched_text: str
    is_baseline: bool = False


# =============================================================================
# Secret Scanner Class
# =============================================================================

class SecretScanner:
    """Scan for secrets in codebase."""

    # Default patterns (used when policy.yaml not available)
    DEFAULT_PATTERNS = [
        {
            "name": "Private Key",
            "pattern": r"-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----",
            "severity": "critical",
        },
        {
            "name": "AWS Access Key",
            "pattern": r"(?:A3T[A-Z0-9]|AKIA|AGPA|AIDA|AROA|AIPA|ANPA|ANVA|ASIA)[0-9A-Z]{16}",
            "severity": "critical",
        },
        {
            "name": "GitHub Token",
            "pattern": r"ghp_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]{36}|ghu_[a-zA-Z0-9]{36}|ghs_[a-zA-Z0-9]{36}",
            "severity": "critical",
        },
        {
            "name": "Generic API Key",
            "pattern": r"(?i)(?:api[_-]?key|apikey)\s*[=:]\s*['\"][a-zA-Z0-9_\-]{20,}['\"]",
            "severity": "high",
        },
        {
            "name": "Password",
            "pattern": r"(?i)password\s*[=:]\s*['\"][^'\"]{8,}['\"]",
            "severity": "high",
        },
        {
            "name": "Generic Secret",
            "pattern": r"(?i)(?:secret|token)\s*[=:]\s*['\"][a-zA-Z0-9_\-]{20,}['\"]",
            "severity": "medium",
        },
    ]

    # Paths to always exclude
    DEFAULT_EXCLUDES = [
        ".git/",
        "node_modules/",
        "__pycache__/",
        ".venv/",
        "venv/",
        "*.lock",
        "package-lock.json",
        "yarn.lock",
        "poetry.lock",
    ]

    def __init__(self, repo_root: Path):
        """Initialize secret scanner.

        Args:
            repo_root: Path to repository root
        """
        self.repo_root = repo_root
        self._policy = None
        self._detect_secrets_available = None

    @property
    def policy(self):
        """Load policy configuration."""
        if self._policy is None:
            try:
                from common.policy_loader import load_policy
                self._policy = load_policy(self.repo_root)
            except Exception:
                self._policy = None
        return self._policy

    @property
    def detect_secrets_available(self) -> bool:
        """Check if detect-secrets is available."""
        if self._detect_secrets_available is None:
            try:
                result = subprocess.run(
                    ["detect-secrets", "--version"],
                    capture_output=True,
                    text=True,
                )
                self._detect_secrets_available = result.returncode == 0
            except Exception:
                self._detect_secrets_available = False
        return self._detect_secrets_available

    def get_patterns(self) -> list[dict[str, str]]:
        """Get secret patterns to scan for."""
        if self.policy and self.policy.custom_secret_patterns:
            return [
                {"name": p.name, "pattern": p.pattern, "severity": p.severity}
                for p in self.policy.custom_secret_patterns
            ]
        return self.DEFAULT_PATTERNS

    def get_exclude_paths(self) -> list[str]:
        """Get paths to exclude from scanning."""
        if self.policy and self.policy.secret_exclude_paths:
            return self.policy.secret_exclude_paths
        return self.DEFAULT_EXCLUDES

    def should_exclude(self, file_path: str) -> bool:
        """Check if a file should be excluded from scanning."""
        import fnmatch

        excludes = self.get_exclude_paths()
        path_str = str(file_path).replace("\\", "/")

        for pattern in excludes:
            if fnmatch.fnmatch(path_str, pattern):
                return True
            if fnmatch.fnmatch(Path(file_path).name, pattern):
                return True

        return False

    def scan_file(self, file_path: Path) -> list[SecretFinding]:
        """Scan a single file for secrets.

        Args:
            file_path: Path to file to scan

        Returns:
            List of SecretFinding objects
        """
        findings = []

        if self.should_exclude(str(file_path)):
            return findings

        if not file_path.is_file():
            return findings

        # Skip binary files
        try:
            content = file_path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            return findings

        patterns = self.get_patterns()

        for line_num, line in enumerate(content.splitlines(), 1):
            for pattern_info in patterns:
                try:
                    matches = re.findall(pattern_info["pattern"], line)
                    for match in matches:
                        # Truncate matched text for display
                        matched_text = str(match)[:50] if len(str(match)) > 50 else str(match)
                        findings.append(SecretFinding(
                            file=str(file_path.relative_to(self.repo_root)),
                            line=line_num,
                            type=pattern_info["name"],
                            severity=pattern_info.get("severity", "medium"),
                            matched_text=matched_text,
                        ))
                except re.error:
                    continue

        return findings

    def scan_files(self, files: list[Path]) -> list[SecretFinding]:
        """Scan multiple files for secrets.

        Args:
            files: List of file paths to scan

        Returns:
            List of SecretFinding objects
        """
        all_findings = []

        for file_path in files:
            findings = self.scan_file(Path(file_path))
            all_findings.extend(findings)

        return all_findings

    def scan_staged(self) -> list[SecretFinding]:
        """Scan staged git changes.

        Returns:
            List of SecretFinding objects
        """
        # Get staged files
        result = subprocess.run(
            ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"],
            capture_output=True,
            text=True,
            cwd=self.repo_root,
        )

        if result.returncode != 0:
            return []

        files = [
            self.repo_root / f.strip()
            for f in result.stdout.strip().split("\n")
            if f.strip()
        ]

        return self.scan_files(files)

    def scan_diff(self, base_branch: str = "main") -> list[SecretFinding]:
        """Scan files changed compared to base branch.

        Args:
            base_branch: Base branch to compare against

        Returns:
            List of SecretFinding objects
        """
        # Get changed files
        result = subprocess.run(
            ["git", "diff", f"origin/{base_branch}", "--name-only", "--diff-filter=ACMR"],
            capture_output=True,
            text=True,
            cwd=self.repo_root,
        )

        if result.returncode != 0:
            # Try without origin/
            result = subprocess.run(
                ["git", "diff", base_branch, "--name-only", "--diff-filter=ACMR"],
                capture_output=True,
                text=True,
                cwd=self.repo_root,
            )

        if result.returncode != 0:
            return []

        files = [
            self.repo_root / f.strip()
            for f in result.stdout.strip().split("\n")
            if f.strip()
        ]

        return self.scan_files(files)

    def scan_with_detect_secrets(self) -> tuple[bool, list[dict[str, Any]]]:
        """Scan using detect-secrets tool.

        Returns:
            Tuple of (success, findings)
        """
        if not self.detect_secrets_available:
            return False, []

        baseline_file = self.repo_root / ".secrets.baseline"

        try:
            # Run detect-secrets scan
            result = subprocess.run(
                ["detect-secrets", "scan", "--baseline", str(baseline_file)]
                + ["--all-files"] if baseline_file.exists() else [],
                capture_output=True,
                text=True,
                cwd=self.repo_root,
            )

            if result.returncode != 0:
                return False, []

            findings = json.loads(result.stdout)
            return True, findings.get("results", {})

        except Exception as e:
            print(f"Error running detect-secrets: {e}", file=sys.stderr)
            return False, []

    def update_baseline(self) -> bool:
        """Update detect-secrets baseline file.

        Returns:
            True if successful
        """
        if not self.detect_secrets_available:
            print("detect-secrets not available", file=sys.stderr)
            return False

        baseline_file = self.repo_root / ".secrets.baseline"

        try:
            result = subprocess.run(
                ["detect-secrets", "scan", "--baseline", str(baseline_file), "."],
                capture_output=True,
                text=True,
                cwd=self.repo_root,
            )

            if result.returncode == 0:
                print(f"Updated baseline: {baseline_file}")
                return True
            else:
                print(f"Failed to update baseline: {result.stderr}", file=sys.stderr)
                return False

        except Exception as e:
            print(f"Error updating baseline: {e}", file=sys.stderr)
            return False

    def filter_baseline(self, findings: list[SecretFinding]) -> list[SecretFinding]:
        """Filter out findings that are in the baseline.

        Args:
            findings: List of findings to filter

        Returns:
            List of new (non-baseline) findings
        """
        baseline_file = self.repo_root / ".secrets.baseline"

        if not baseline_file.exists():
            return findings

        try:
            with open(baseline_file, "r", encoding="utf-8") as f:
                baseline = json.load(f)

            baseline_secrets = baseline.get("results", {})
            new_findings = []

            for finding in findings:
                file_secrets = baseline_secrets.get(finding.file, [])
                is_in_baseline = any(
                    secret.get("line_number") == finding.line
                    for secret in file_secrets
                )

                if not is_in_baseline:
                    new_findings.append(finding)

            return new_findings

        except Exception:
            return findings


# =============================================================================
# CLI Interface
# =============================================================================

def get_repo_root() -> Path:
    """Find repository root."""
    current = Path.cwd()
    while current != current.parent:
        if (current / ".git").exists():
            return current
        current = current.parent
    return Path.cwd()


def print_findings(findings: list[SecretFinding], format: str = "text") -> None:
    """Print findings in specified format."""
    if format == "json":
        output = [
            {
                "file": f.file,
                "line": f.line,
                "type": f.type,
                "severity": f.severity,
                "matched_text": f.matched_text,
            }
            for f in findings
        ]
        print(json.dumps(output, indent=2))
    else:
        if not findings:
            print("No secrets found.")
            return

        # Group by severity
        critical = [f for f in findings if f.severity == "critical"]
        high = [f for f in findings if f.severity == "high"]
        medium = [f for f in findings if f.severity == "medium"]

        for severity_name, severity_findings in [("CRITICAL", critical), ("HIGH", high), ("MEDIUM", medium)]:
            if severity_findings:
                print(f"\n{severity_name}:")
                for f in severity_findings:
                    print(f"  {f.file}:{f.line} [{f.type}]")
                    print(f"    Matched: {f.matched_text}")


def main() -> int:
    """CLI entry point."""
    import argparse

    parser = argparse.ArgumentParser(description="Scan for secrets in codebase")
    parser.add_argument("--staged", action="store_true", help="Scan staged changes")
    parser.add_argument("--diff", metavar="BRANCH", help="Scan diff against branch")
    parser.add_argument("--files", nargs="+", help="Scan specific files")
    parser.add_argument("--update-baseline", action="store_true", help="Update detect-secrets baseline")
    parser.add_argument("--format", choices=["text", "json"], default="text", help="Output format")
    parser.add_argument("--fail-on-secrets", action="store_true", help="Exit with error if secrets found")

    args = parser.parse_args()

    repo_root = get_repo_root()
    scanner = SecretScanner(repo_root)

    if args.update_baseline:
        success = scanner.update_baseline()
        return 0 if success else 1

    findings = []

    if args.staged:
        findings = scanner.scan_staged()
    elif args.diff:
        findings = scanner.scan_diff(args.diff)
    elif args.files:
        findings = scanner.scan_files([Path(f) for f in args.files])
    else:
        # Default: scan staged
        findings = scanner.scan_staged()

    # Filter out baseline secrets
    findings = scanner.filter_baseline(findings)

    print_findings(findings, args.format)

    if args.fail_on_secrets and findings:
        # Check for high/critical severity
        critical_high = [f for f in findings if f.severity in ("critical", "high")]
        if critical_high:
            return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
