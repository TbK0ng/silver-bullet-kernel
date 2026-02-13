#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Workflow Doctor - Diagnose workflow health and configuration issues.

Performs comprehensive health checks on the workflow setup and
provides actionable remediation guidance.

Usage:
    python3 doctor.py
    python3 doctor.py --json
    python3 doctor.py --fix
"""

from __future__ import annotations

import json
import os
import platform
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Callable

# Handle Windows encoding
if sys.platform == "win32":
    import io as _io
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")


# =============================================================================
# Data Classes
# =============================================================================

@dataclass
class CheckResult:
    """Result of a single doctor check."""
    id: str
    name: str
    description: str
    passed: bool
    critical: bool
    message: str
    remediation: str | None = None
    details: dict[str, Any] | None = None


@dataclass
class DoctorReport:
    """Complete doctor report."""
    timestamp: str
    overall_status: str  # "healthy", "degraded", "critical"
    checks: list[CheckResult]
    passed_count: int
    failed_count: int
    critical_failed: int


# =============================================================================
# Doctor Checks
# =============================================================================

class WorkflowDoctor:
    """Diagnose workflow health."""

    def __init__(self, repo_root: Path):
        """Initialize workflow doctor.

        Args:
            repo_root: Path to repository root
        """
        self.repo_root = repo_root
        self.results: list[CheckResult] = []
        self._policy = None

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

    def run_all_checks(self) -> list[CheckResult]:
        """Run all doctor checks."""
        self.results = []

        # Core checks
        self._check_git_repo()
        self._check_developer_identity()
        self._check_trellis_structure()
        self._check_openspec_structure()
        self._check_policy_file()
        self._check_secret_baseline()
        self._check_python_version()
        self._check_hooks_configured()
        self._check_claude_settings()
        self._check_workspace_directory()
        self._check_tasks_directory()
        self._check_metrics_directory()
        self._check_gotchas_directory()

        return self.results

    def _add_result(self, result: CheckResult) -> None:
        """Add a check result."""
        self.results.append(result)

    def _check_git_repo(self) -> None:
        """Check if inside a git repository."""
        git_dir = self.repo_root / ".git"
        passed = git_dir.exists() and git_dir.is_dir()

        self._add_result(CheckResult(
            id="git_repo",
            name="Git Repository",
            description="Check if inside a git repository",
            passed=passed,
            critical=True,
            message="Git repository found" if passed else "Not a git repository",
            remediation=None if passed else "Run 'git init' to initialize a repository",
        ))

    def _check_developer_identity(self) -> None:
        """Check if developer identity is set."""
        developer_file = self.repo_root / ".trellis" / ".developer"
        passed = developer_file.exists()

        developer_name = None
        if passed:
            try:
                developer_name = developer_file.read_text(encoding="utf-8").strip()
            except Exception:
                pass

        self._add_result(CheckResult(
            id="developer_identity",
            name="Developer Identity",
            description="Check if developer identity is set",
            passed=passed,
            critical=True,
            message=f"Developer: {developer_name}" if passed else "Developer identity not set",
            remediation=None if passed else "Run: uv run .trellis/scripts/init_developer.py <your-name>",
        ))

    def _check_trellis_structure(self) -> None:
        """Check .trellis directory structure."""
        required_dirs = [
            ".trellis",
            ".trellis/scripts",
            ".trellis/spec",
            ".trellis/workspace",
            ".trellis/tasks",
        ]

        missing = []
        for dir_path in required_dirs:
            full_path = self.repo_root / dir_path
            if not full_path.is_dir():
                missing.append(dir_path)

        passed = len(missing) == 0

        self._add_result(CheckResult(
            id="trellis_structure",
            name="Trellis Directory Structure",
            description="Check required .trellis directories exist",
            passed=passed,
            critical=True,
            message="All required directories exist" if passed else f"Missing: {', '.join(missing)}",
            remediation=None if passed else "Run: trellis init or create missing directories",
        ))

    def _check_openspec_structure(self) -> None:
        """Check openspec directory structure."""
        required_dirs = [
            "openspec",
            "openspec/specs",
            "openspec/changes",
        ]

        missing = []
        for dir_path in required_dirs:
            full_path = self.repo_root / dir_path
            if not full_path.is_dir():
                missing.append(dir_path)

        passed = len(missing) == 0

        self._add_result(CheckResult(
            id="openspec_structure",
            name="OpenSpec Directory Structure",
            description="Check openspec directories exist",
            passed=passed,
            critical=False,
            message="OpenSpec structure found" if passed else f"Missing: {', '.join(missing)}",
            remediation=None if passed else "Run: openspec init",
        ))

    def _check_policy_file(self) -> None:
        """Check policy.yaml exists and is valid."""
        policy_file = self.repo_root / ".trellis" / "policy.yaml"

        if not policy_file.exists():
            self._add_result(CheckResult(
                id="policy_file",
                name="Policy Configuration",
                description="Check policy.yaml exists and is valid",
                passed=False,
                critical=False,
                message="policy.yaml not found",
                remediation="Create .trellis/policy.yaml with workflow policies",
            ))
            return

        # Validate policy file
        try:
            from common.policy_loader import PolicyLoader
            loader = PolicyLoader(self.repo_root)
            errors = loader.validate()

            if errors:
                self._add_result(CheckResult(
                    id="policy_file",
                    name="Policy Configuration",
                    description="Check policy.yaml exists and is valid",
                    passed=False,
                    critical=False,
                    message=f"Policy has errors: {'; '.join(errors)}",
                    remediation="Fix policy.yaml validation errors",
                ))
            else:
                self._add_result(CheckResult(
                    id="policy_file",
                    name="Policy Configuration",
                    description="Check policy.yaml exists and is valid",
                    passed=True,
                    critical=False,
                    message="policy.yaml is valid",
                ))

        except Exception as e:
            self._add_result(CheckResult(
                id="policy_file",
                name="Policy Configuration",
                description="Check policy.yaml exists and is valid",
                passed=False,
                critical=False,
                message=f"Failed to validate policy: {e}",
                remediation="Check policy.yaml syntax",
            ))

    def _check_secret_baseline(self) -> None:
        """Check detect-secrets baseline exists."""
        baseline_file = self.repo_root / ".secrets.baseline"
        passed = baseline_file.exists()

        # Check if detect-secrets is available
        ds_available = False
        try:
            result = subprocess.run(
                ["detect-secrets", "--version"],
                capture_output=True,
            )
            ds_available = result.returncode == 0
        except Exception:
            pass

        if not ds_available:
            self._add_result(CheckResult(
                id="secret_baseline",
                name="Secret Scan Baseline",
                description="Check detect-secrets baseline exists",
                passed=False,
                critical=False,
                message="detect-secrets not installed",
                remediation="pip install detect-secrets",
                details={"detect_secrets_available": False},
            ))
            return

        self._add_result(CheckResult(
            id="secret_baseline",
            name="Secret Scan Baseline",
            description="Check detect-secrets baseline exists",
            passed=passed,
            critical=False,
            message="Baseline exists" if passed else "Baseline not found",
            remediation=None if passed else "Run: detect-secrets scan > .secrets.baseline",
            details={"detect_secrets_available": True},
        ))

    def _check_python_version(self) -> None:
        """Check Python version >= 3.10."""
        version = sys.version_info
        passed = version >= (3, 10)

        self._add_result(CheckResult(
            id="python_version",
            name="Python Version",
            description="Check Python version >= 3.10",
            passed=passed,
            critical=True,
            message=f"Python {version.major}.{version.minor}.{version.micro}",
            remediation=None if passed else "Upgrade to Python 3.10 or higher",
        ))

    def _check_hooks_configured(self) -> None:
        """Check Claude Code hooks are configured."""
        settings_file = self.repo_root / ".claude" / "settings.json"

        if not settings_file.exists():
            self._add_result(CheckResult(
                id="hooks_configured",
                name="Hooks Configuration",
                description="Check Claude Code hooks are configured",
                passed=False,
                critical=False,
                message="Claude settings not found",
                remediation="Ensure .claude/settings.json exists with hook configuration",
            ))
            return

        try:
            with open(settings_file, "r", encoding="utf-8") as f:
                settings = json.load(f)

            hooks = settings.get("hooks", {})
            has_session_start = "SessionStart" in hooks
            has_pre_tool_use = "PreToolUse" in hooks

            if has_session_start and has_pre_tool_use:
                self._add_result(CheckResult(
                    id="hooks_configured",
                    name="Hooks Configuration",
                    description="Check Claude Code hooks are configured",
                    passed=True,
                    critical=False,
                    message="Hooks configured: SessionStart, PreToolUse",
                ))
            else:
                missing = []
                if not has_session_start:
                    missing.append("SessionStart")
                if not has_pre_tool_use:
                    missing.append("PreToolUse")

                self._add_result(CheckResult(
                    id="hooks_configured",
                    name="Hooks Configuration",
                    description="Check Claude Code hooks are configured",
                    passed=False,
                    critical=False,
                    message=f"Missing hooks: {', '.join(missing)}",
                    remediation="Add missing hooks to .claude/settings.json",
                ))

        except Exception as e:
            self._add_result(CheckResult(
                id="hooks_configured",
                name="Hooks Configuration",
                description="Check Claude Code hooks are configured",
                passed=False,
                critical=False,
                message=f"Failed to read settings: {e}",
                remediation="Check .claude/settings.json format",
            ))

    def _check_claude_settings(self) -> None:
        """Check .claude/settings.json format."""
        settings_file = self.repo_root / ".claude" / "settings.json"

        if not settings_file.exists():
            self._add_result(CheckResult(
                id="claude_settings",
                name="Claude Settings Format",
                description="Check .claude/settings.json is valid JSON",
                passed=True,  # Not critical if missing
                critical=False,
                message="Claude settings not found (optional)",
            ))
            return

        try:
            with open(settings_file, "r", encoding="utf-8") as f:
                json.load(f)

            self._add_result(CheckResult(
                id="claude_settings",
                name="Claude Settings Format",
                description="Check .claude/settings.json is valid JSON",
                passed=True,
                critical=False,
                message="Settings file is valid JSON",
            ))

        except json.JSONDecodeError as e:
            self._add_result(CheckResult(
                id="claude_settings",
                name="Claude Settings Format",
                description="Check .claude/settings.json is valid JSON",
                passed=False,
                critical=False,
                message=f"Invalid JSON: {e}",
                remediation="Fix JSON syntax in .claude/settings.json",
            ))

    def _check_workspace_directory(self) -> None:
        """Check workspace directory has at least one developer."""
        workspace_dir = self.repo_root / ".trellis" / "workspace"

        if not workspace_dir.exists():
            self._add_result(CheckResult(
                id="workspace_directory",
                name="Workspace Directory",
                description="Check workspace directory exists",
                passed=False,
                critical=False,
                message="Workspace directory not found",
                remediation="Run: mkdir -p .trellis/workspace",
            ))
            return

        # Check for developer subdirectories
        developer_dirs = [d for d in workspace_dir.iterdir() if d.is_dir() and not d.name.startswith(".")]

        self._add_result(CheckResult(
            id="workspace_directory",
            name="Workspace Directory",
            description="Check workspace directory exists",
            passed=True,
            critical=False,
            message=f"Found {len(developer_dirs)} developer workspace(s)",
            details={"developer_count": len(developer_dirs)},
        ))

    def _check_tasks_directory(self) -> None:
        """Check tasks directory structure."""
        tasks_dir = self.repo_root / ".trellis" / "tasks"

        if not tasks_dir.exists():
            self._add_result(CheckResult(
                id="tasks_directory",
                name="Tasks Directory",
                description="Check tasks directory exists",
                passed=False,
                critical=False,
                message="Tasks directory not found",
                remediation="Run: mkdir -p .trellis/tasks",
            ))
            return

        # Count active tasks
        active_tasks = [
            d for d in tasks_dir.iterdir()
            if d.is_dir() and d.name != "archive"
        ]

        self._add_result(CheckResult(
            id="tasks_directory",
            name="Tasks Directory",
            description="Check tasks directory exists",
            passed=True,
            critical=False,
            message=f"Found {len(active_tasks)} active task(s)",
            details={"active_tasks": len(active_tasks)},
        ))

    def _check_metrics_directory(self) -> None:
        """Check metrics directory exists."""
        metrics_dir = self.repo_root / ".trellis" / "metrics"

        if not metrics_dir.exists():
            self._add_result(CheckResult(
                id="metrics_directory",
                name="Metrics Directory",
                description="Check metrics directory exists",
                passed=False,
                critical=False,
                message="Metrics directory not found",
                remediation="Run: mkdir -p .trellis/metrics/daily",
            ))
            return

        # Count daily metric files
        daily_dir = metrics_dir / "daily"
        metric_files = list(daily_dir.glob("metrics-*.json")) if daily_dir.exists() else []

        self._add_result(CheckResult(
            id="metrics_directory",
            name="Metrics Directory",
            description="Check metrics directory exists",
            passed=True,
            critical=False,
            message=f"Found {len(metric_files)} daily metric file(s)",
            details={"metric_files": len(metric_files)},
        ))

    def _check_gotchas_directory(self) -> None:
        """Check gotchas directory exists for failure assetization."""
        gotchas_dir = self.repo_root / ".trellis" / "gotchas"

        if not gotchas_dir.exists():
            self._add_result(CheckResult(
                id="gotchas_directory",
                name="Gotchas Directory",
                description="Check gotchas directory exists for failure assetization",
                passed=False,
                critical=False,
                message="Gotchas directory not found",
                remediation="Run: mkdir -p .trellis/gotchas",
            ))
            return

        # Count gotcha files
        gotcha_files = list(gotchas_dir.glob("*.md"))
        has_index = (gotchas_dir / "index.md").exists()

        self._add_result(CheckResult(
            id="gotchas_directory",
            name="Gotchas Directory",
            description="Check gotchas directory exists for failure assetization",
            passed=True,
            critical=False,
            message=f"Found {len(gotcha_files)} gotcha file(s), index: {'yes' if has_index else 'no'}",
            details={"gotcha_files": len(gotcha_files), "has_index": has_index},
        ))

    def generate_report(self) -> DoctorReport:
        """Generate complete doctor report."""
        if not self.results:
            self.run_all_checks()

        passed_count = sum(1 for r in self.results if r.passed)
        failed_count = sum(1 for r in self.results if not r.passed)
        critical_failed = sum(1 for r in self.results if not r.passed and r.critical)

        if critical_failed > 0:
            overall_status = "critical"
        elif failed_count > 0:
            overall_status = "degraded"
        else:
            overall_status = "healthy"

        return DoctorReport(
            timestamp=datetime.now().isoformat(),
            overall_status=overall_status,
            checks=self.results,
            passed_count=passed_count,
            failed_count=failed_count,
            critical_failed=critical_failed,
        )

    def print_report(self, format: str = "text") -> None:
        """Print doctor report."""
        report = self.generate_report()

        if format == "json":
            output = {
                "timestamp": report.timestamp,
                "overall_status": report.overall_status,
                "passed_count": report.passed_count,
                "failed_count": report.failed_count,
                "critical_failed": report.critical_failed,
                "checks": [
                    {
                        "id": c.id,
                        "name": c.name,
                        "passed": c.passed,
                        "critical": c.critical,
                        "message": c.message,
                        "remediation": c.remediation,
                    }
                    for c in report.checks
                ],
            }
            print(json.dumps(output, indent=2))
        else:
            # Text format
            status_emoji = {"healthy": "✓", "degraded": "⚠", "critical": "✗"}
            status_color = {"healthy": "\033[32m", "degraded": "\033[33m", "critical": "\033[31m"}
            reset = "\033[0m"

            print("\n" + "=" * 60)
            print("WORKFLOW DOCTOR REPORT")
            print("=" * 60)
            print(f"\nTimestamp: {report.timestamp}")
            print(f"Overall Status: {status_color[report.overall_status]}{report.overall_status.upper()}{reset}")
            print(f"Checks: {report.passed_count} passed, {report.failed_count} failed ({report.critical_failed} critical)")
            print()

            for check in report.checks:
                status = "✓" if check.passed else ("✗" if check.critical else "⚠")
                color = "\033[32m" if check.passed else ("\033[31m" if check.critical else "\033[33m")

                print(f"{color}{status}{reset} {check.name}")
                print(f"    {check.message}")
                if check.remediation:
                    print(f"    → {check.remediation}")
                print()

            print("=" * 60)


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


def main() -> int:
    """CLI entry point."""
    import argparse

    parser = argparse.ArgumentParser(description="Diagnose workflow health")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument("--fix", action="store_true", help="Attempt to fix issues")

    args = parser.parse_args()

    repo_root = get_repo_root()
    doctor = WorkflowDoctor(repo_root)

    format_type = "json" if args.json else "text"
    doctor.print_report(format=format_type)

    report = doctor.generate_report()

    # Exit with error code if critical failures
    if report.critical_failed > 0:
        return 1
    elif report.failed_count > 0:
        return 2  # Non-critical failures
    else:
        return 0


if __name__ == "__main__":
    sys.exit(main())
