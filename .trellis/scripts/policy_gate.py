#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Policy Gate - Enforce workflow policies and thresholds.

Validates code changes and workflow state against policy.yaml
configuration. Used in CI/CD pipelines and pre-commit hooks.

Usage:
    # Check all policy gates
    python3 policy_gate.py

    # Check specific gates
    python3 policy_gate.py --gate sensitive_paths
    python3 policy_gate.py --gate secrets
    python3 policy_gate.py --gate thresholds

    # For CI integration
    python3 policy_gate.py --ci
"""

from __future__ import annotations

import json
import subprocess
import sys
from dataclasses import dataclass
from datetime import date, timedelta
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
class GateResult:
    """Result of a single policy gate check."""
    gate: str
    passed: bool
    severity: str  # "error", "warning", "info"
    message: str
    details: dict[str, Any] | None = None


@dataclass
class PolicyGateReport:
    """Complete policy gate report."""
    passed: bool
    gates: list[GateResult]
    error_count: int
    warning_count: int


# =============================================================================
# Policy Gate Checker
# =============================================================================

class PolicyGate:
    """Enforce workflow policies."""

    def __init__(self, repo_root: Path):
        """Initialize policy gate.

        Args:
            repo_root: Path to repository root
        """
        self.repo_root = repo_root
        self._policy = None
        self._policy_loader = None
        self.results: list[GateResult] = []

    @property
    def policy_loader(self):
        """Get policy loader."""
        if self._policy_loader is None:
            try:
                from common.policy_loader import PolicyLoader
                self._policy_loader = PolicyLoader(self.repo_root)
            except Exception:
                pass
        return self._policy_loader

    @property
    def policy(self):
        """Load policy configuration."""
        if self._policy is None and self.policy_loader:
            self._policy = self.policy_loader.load()
        return self._policy

    def run_all_gates(self, ci_mode: bool = False) -> list[GateResult]:
        """Run all policy gate checks."""
        self.results = []

        # Always run these gates
        self._gate_sensitive_paths()
        self._gate_secrets()

        # Run threshold gates if metrics available
        self._gate_verify_failure_rate()
        self._gate_rework_count()
        self._gate_spec_drift()

        # Session evidence gate (CI only)
        if ci_mode:
            self._gate_session_evidence()

        return self.results

    def _add_result(self, result: GateResult) -> None:
        """Add a gate result."""
        self.results.append(result)

    def _get_changed_files(self) -> list[str]:
        """Get list of changed files (staged or compared to main)."""
        files = []

        # Try staged first
        result = subprocess.run(
            ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"],
            capture_output=True,
            text=True,
            cwd=self.repo_root,
        )

        if result.returncode == 0 and result.stdout.strip():
            files = result.stdout.strip().split("\n")
        else:
            # Try compared to main
            result = subprocess.run(
                ["git", "diff", "origin/main", "--name-only", "--diff-filter=ACMR"],
                capture_output=True,
                text=True,
                cwd=self.repo_root,
            )

            if result.returncode != 0:
                result = subprocess.run(
                    ["git", "diff", "main", "--name-only", "--diff-filter=ACMR"],
                    capture_output=True,
                    text=True,
                    cwd=self.repo_root,
                )

            if result.returncode == 0 and result.stdout.strip():
                files = result.stdout.strip().split("\n")

        return [f.strip() for f in files if f.strip()]

    def _gate_sensitive_paths(self) -> None:
        """Check if changed files touch sensitive paths."""
        changed_files = self._get_changed_files()

        if not changed_files:
            self._add_result(GateResult(
                gate="sensitive_paths",
                passed=True,
                severity="info",
                message="No changed files to check",
            ))
            return

        denied = []
        warned = []

        for file_path in changed_files:
            if self.policy_loader and self.policy_loader.is_path_denied(file_path):
                denied.append(file_path)
            elif self.policy_loader and self.policy_loader.is_path_warned(file_path):
                warned.append(file_path)

        if denied:
            self._add_result(GateResult(
                gate="sensitive_paths",
                passed=False,
                severity="error",
                message=f"Changed files touch denylisted paths: {', '.join(denied)}",
                details={"denied": denied, "warned": warned},
            ))
        elif warned:
            self._add_result(GateResult(
                gate="sensitive_paths",
                passed=True,
                severity="warning",
                message=f"Changed files touch sensitive paths (warning): {', '.join(warned)}",
                details={"warned": warned},
            ))
        else:
            self._add_result(GateResult(
                gate="sensitive_paths",
                passed=True,
                severity="info",
                message="No sensitive path violations",
            ))

    def _gate_secrets(self) -> None:
        """Check for leaked secrets in changed files."""
        try:
            from secret_scan import SecretScanner
            scanner = SecretScanner(self.repo_root)

            # Scan staged changes
            findings = scanner.scan_staged()
            findings = scanner.filter_baseline(findings)

            if not findings:
                self._add_result(GateResult(
                    gate="secrets",
                    passed=True,
                    severity="info",
                    message="No secrets detected",
                ))
                return

            # Check for critical/high severity
            critical_high = [f for f in findings if f.severity in ("critical", "high")]

            if critical_high:
                self._add_result(GateResult(
                    gate="secrets",
                    passed=False,
                    severity="error",
                    message=f"Found {len(critical_high)} critical/high severity secret(s)",
                    details={
                        "critical": len([f for f in findings if f.severity == "critical"]),
                        "high": len([f for f in findings if f.severity == "high"]),
                        "medium": len([f for f in findings if f.severity == "medium"]),
                    },
                ))
            else:
                self._add_result(GateResult(
                    gate="secrets",
                    passed=True,
                    severity="warning",
                    message=f"Found {len(findings)} medium severity secret(s) - review recommended",
                    details={"findings": len(findings)},
                ))

        except ImportError:
            self._add_result(GateResult(
                gate="secrets",
                passed=True,
                severity="warning",
                message="Secret scanner not available",
            ))

    def _gate_verify_failure_rate(self) -> None:
        """Check verify failure rate against threshold."""
        try:
            from collect_metrics import MetricsCollector
            collector = MetricsCollector(self.repo_root)

            # Get last 7 days of metrics
            end_date = date.today()
            start_date = end_date - timedelta(days=7)

            aggregated = collector.aggregate_range(start_date, end_date)
            failure_rate = aggregated.get("verify_failure_rate", 0.0)

            if self.policy_loader:
                status = self.policy_loader.evaluate_threshold("verify_failure_rate", failure_rate)
            else:
                status = "fail" if failure_rate > 0.5 else ("warn" if failure_rate > 0.2 else "pass")

            passed = status == "pass"
            severity = "error" if status == "fail" else ("warning" if status == "warn" else "info")

            self._add_result(GateResult(
                gate="verify_failure_rate",
                passed=passed,
                severity=severity,
                message=f"Verify failure rate: {failure_rate:.1%} (status: {status})",
                details={"failure_rate": failure_rate, "status": status},
            ))

        except Exception as e:
            self._add_result(GateResult(
                gate="verify_failure_rate",
                passed=True,
                severity="info",
                message=f"Could not calculate failure rate: {e}",
            ))

    def _gate_rework_count(self) -> None:
        """Check rework count against threshold."""
        try:
            from collect_metrics import MetricsCollector
            collector = MetricsCollector(self.repo_root)

            # Get last 7 days of metrics
            end_date = date.today()
            start_date = end_date - timedelta(days=7)

            aggregated = collector.aggregate_range(start_date, end_date)
            rework_count = aggregated.get("rework_events", 0)

            if self.policy_loader:
                threshold = self.policy_loader.get_threshold("rework_count")
                if threshold:
                    status = "fail" if rework_count >= threshold.fail else ("warn" if rework_count >= threshold.warn else "pass")
                else:
                    status = "pass"
            else:
                status = "fail" if rework_count >= 5 else ("warn" if rework_count >= 3 else "pass")

            passed = status == "pass"
            severity = "error" if status == "fail" else ("warning" if status == "warn" else "info")

            self._add_result(GateResult(
                gate="rework_count",
                passed=passed,
                severity=severity,
                message=f"Rework events (7 days): {rework_count} (status: {status})",
                details={"rework_count": rework_count, "status": status},
            ))

        except Exception as e:
            self._add_result(GateResult(
                gate="rework_count",
                passed=True,
                severity="info",
                message=f"Could not calculate rework count: {e}",
            ))

    def _gate_spec_drift(self) -> None:
        """Check spec drift events against threshold."""
        try:
            from collect_metrics import MetricsCollector
            collector = MetricsCollector(self.repo_root)

            # Get last 7 days of metrics
            end_date = date.today()
            start_date = end_date - timedelta(days=7)

            aggregated = collector.aggregate_range(start_date, end_date)
            drift_count = aggregated.get("spec_drift_events", 0)

            if self.policy_loader:
                threshold = self.policy_loader.get_threshold("spec_drift_weekly")
                if threshold:
                    status = "fail" if drift_count >= threshold.fail else ("warn" if drift_count >= threshold.warn else "pass")
                else:
                    status = "pass"
            else:
                status = "fail" if drift_count >= 10 else ("warn" if drift_count >= 3 else "pass")

            passed = status == "pass"
            severity = "error" if status == "fail" else ("warning" if status == "warn" else "info")

            self._add_result(GateResult(
                gate="spec_drift",
                passed=passed,
                severity=severity,
                message=f"Spec drift events (7 days): {drift_count} (status: {status})",
                details={"drift_count": drift_count, "status": status},
            ))

        except Exception as e:
            self._add_result(GateResult(
                gate="spec_drift",
                passed=True,
                severity="info",
                message=f"Could not calculate spec drift: {e}",
            ))

    def _gate_session_evidence(self) -> None:
        """Check session evidence for implementation changes (CI only)."""
        # Get implementation file changes
        impl_patterns = ["src/", "lib/", "app/", "components/", "pages/"]
        changed_files = self._get_changed_files()

        impl_changes = []
        for f in changed_files:
            for pattern in impl_patterns:
                if f.startswith(pattern):
                    impl_changes.append(f)
                    break

        if not impl_changes:
            self._add_result(GateResult(
                gate="session_evidence",
                passed=True,
                severity="info",
                message="No implementation file changes to validate",
            ))
            return

        # Check for session evidence updates
        # This is a simplified check - in practice would need more sophisticated logic
        workspace_dir = self.repo_root / ".trellis" / "workspace"
        session_updated = False

        if workspace_dir.exists():
            # Check if any journal files were modified recently
            result = subprocess.run(
                ["git", "log", "--oneline", "-1", "--", ".trellis/workspace/"],
                capture_output=True,
                text=True,
                cwd=self.repo_root,
            )
            session_updated = result.returncode == 0 and result.stdout.strip()

        if session_updated:
            self._add_result(GateResult(
                gate="session_evidence",
                passed=True,
                severity="info",
                message="Session evidence found for implementation changes",
            ))
        else:
            self._add_result(GateResult(
                gate="session_evidence",
                passed=True,  # Warning, not failure
                severity="warning",
                message="Implementation changes may lack session evidence",
                details={"impl_changes": impl_changes},
            ))

    def generate_report(self) -> PolicyGateReport:
        """Generate complete policy gate report."""
        if not self.results:
            self.run_all_gates()

        error_count = sum(1 for r in self.results if r.severity == "error")
        warning_count = sum(1 for r in self.results if r.severity == "warning")

        passed = error_count == 0

        return PolicyGateReport(
            passed=passed,
            gates=self.results,
            error_count=error_count,
            warning_count=warning_count,
        )

    def print_report(self, format: str = "text") -> None:
        """Print policy gate report."""
        report = self.generate_report()

        if format == "json":
            output = {
                "passed": report.passed,
                "error_count": report.error_count,
                "warning_count": report.warning_count,
                "gates": [
                    {
                        "gate": g.gate,
                        "passed": g.passed,
                        "severity": g.severity,
                        "message": g.message,
                        "details": g.details,
                    }
                    for g in report.gates
                ],
            }
            print(json.dumps(output, indent=2))
        else:
            # Text format
            print("\n" + "=" * 60)
            print("POLICY GATE REPORT")
            print("=" * 60)

            status_str = "PASSED" if report.passed else "FAILED"
            status_color = "\033[32m" if report.passed else "\033[31m"
            reset = "\033[0m"

            print(f"\nOverall: {status_color}{status_str}{reset}")
            print(f"Errors: {report.error_count}, Warnings: {report.warning_count}")
            print()

            for gate in report.gates:
                if gate.severity == "error":
                    icon = "✗"
                    color = "\033[31m"
                elif gate.severity == "warning":
                    icon = "⚠"
                    color = "\033[33m"
                else:
                    icon = "✓"
                    color = "\033[32m"

                print(f"{color}{icon}{reset} [{gate.gate}] {gate.message}")
                if gate.details:
                    for key, value in gate.details.items():
                        print(f"    {key}: {value}")

            print("\n" + "=" * 60)


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

    parser = argparse.ArgumentParser(description="Enforce workflow policies")
    parser.add_argument("--gate", help="Run specific gate only")
    parser.add_argument("--ci", action="store_true", help="CI mode (include session evidence gate)")
    parser.add_argument("--json", action="store_true", help="Output as JSON")

    args = parser.parse_args()

    repo_root = get_repo_root()
    gate = PolicyGate(repo_root)

    if args.gate:
        # Run specific gate
        gate_name = args.gate
        if gate_name == "sensitive_paths":
            gate._gate_sensitive_paths()
        elif gate_name == "secrets":
            gate._gate_secrets()
        elif gate_name == "verify_failure_rate":
            gate._gate_verify_failure_rate()
        elif gate_name == "rework_count":
            gate._gate_rework_count()
        elif gate_name == "spec_drift":
            gate._gate_spec_drift()
        else:
            print(f"Unknown gate: {gate_name}", file=sys.stderr)
            return 1
    else:
        gate.run_all_gates(ci_mode=args.ci)

    format_type = "json" if args.json else "text"
    gate.print_report(format=format_type)

    report = gate.generate_report()
    return 0 if report.passed else 1


if __name__ == "__main__":
    sys.exit(main())
