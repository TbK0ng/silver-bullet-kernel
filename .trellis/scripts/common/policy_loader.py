#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Policy Loader - Load and validate workflow policy configuration.

Provides a centralized way to access policy.yaml configuration across
all workflow scripts.

Usage:
    from common.policy_loader import PolicyLoader

    loader = PolicyLoader(repo_root)
    policy = loader.load()
    thresholds = policy.get_thresholds()
"""

from __future__ import annotations

import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

# Handle YAML import with fallback
try:
    import yaml
    YAML_AVAILABLE = True
except ImportError:
    YAML_AVAILABLE = False

# =============================================================================
# Path Constants
# =============================================================================

POLICY_FILE = "policy.yaml"
DIR_WORKFLOW = ".trellis"


# =============================================================================
# Data Classes for Type-Safe Policy Access
# =============================================================================

@dataclass
class ThresholdConfig:
    """Configuration for a single threshold."""
    warn: float
    fail: float
    description: str = ""


@dataclass
class SecretPattern:
    """Custom secret pattern configuration."""
    name: str
    pattern: str
    severity: str = "medium"


@dataclass
class MemorySource:
    """Approved memory source configuration."""
    path: str
    type: str
    description: str = ""


@dataclass
class DoctorCheck:
    """Doctor check configuration."""
    id: str
    name: str
    description: str
    critical: bool = False


@dataclass
class PolicyConfig:
    """Complete policy configuration."""
    version: str = "1.0"

    # Sensitive paths
    deny_paths: list[str] = field(default_factory=list)
    warn_paths: list[str] = field(default_factory=list)

    # Secret scanning
    secret_scan_enabled: bool = True
    secret_baseline_file: str = ".secrets.baseline"
    custom_secret_patterns: list[SecretPattern] = field(default_factory=list)
    secret_exclude_paths: list[str] = field(default_factory=list)

    # Thresholds
    thresholds: dict[str, ThresholdConfig] = field(default_factory=dict)

    # Memory sources
    approved_memory_sources: list[MemorySource] = field(default_factory=list)
    redact_patterns: list[str] = field(default_factory=list)
    retention_daily_days: int = 90
    retention_weekly_weeks: int = 52

    # Session evidence
    session_evidence_required: bool = True
    session_evidence_fields: list[str] = field(default_factory=list)
    session_evidence_owner_scoped: bool = True

    # Doctor checks
    doctor_checks: list[DoctorCheck] = field(default_factory=list)

    # Metrics
    metrics_on_session_start: bool = True
    metrics_on_session_end: bool = True
    metrics_on_verify_loop: bool = True
    metrics_on_task_complete: bool = True
    metrics_weekly_enabled: bool = True
    metrics_output_dir: str = ".trellis/metrics/weekly"


# =============================================================================
# Policy Loader Class
# =============================================================================

class PolicyLoader:
    """Load and validate workflow policy configuration."""

    def __init__(self, repo_root: Path | str):
        """Initialize policy loader.

        Args:
            repo_root: Path to repository root
        """
        self.repo_root = Path(repo_root)
        self._policy: PolicyConfig | None = None
        self._raw_config: dict[str, Any] = {}

    @property
    def policy_file_path(self) -> Path:
        """Get path to policy.yaml file."""
        return self.repo_root / DIR_WORKFLOW / POLICY_FILE

    def load(self, reload: bool = False) -> PolicyConfig:
        """Load policy configuration.

        Args:
            reload: Force reload even if cached

        Returns:
            PolicyConfig instance
        """
        if self._policy is not None and not reload:
            return self._policy

        # Check if policy file exists
        if not self.policy_file_path.exists():
            # Return default policy
            self._policy = self._create_default_policy()
            return self._policy

        # Load YAML
        if not YAML_AVAILABLE:
            print("Warning: PyYAML not available, using default policy", file=sys.stderr)
            self._policy = self._create_default_policy()
            return self._policy

        try:
            with open(self.policy_file_path, "r", encoding="utf-8") as f:
                self._raw_config = yaml.safe_load(f) or {}
        except Exception as e:
            print(f"Warning: Failed to load policy.yaml: {e}", file=sys.stderr)
            self._policy = self._create_default_policy()
            return self._policy

        self._policy = self._parse_config(self._raw_config)
        return self._policy

    def _create_default_policy(self) -> PolicyConfig:
        """Create default policy configuration."""
        return PolicyConfig(
            deny_paths=[".env", "*.key", "secrets/"],
            warn_paths=["config/*.local.*"],
            thresholds={
                "verify_failure_rate": ThresholdConfig(warn=0.2, fail=0.5, description="Verify failure rate"),
                "rework_count": ThresholdConfig(warn=3, fail=5, description="Rework cycles per task"),
                "lead_time_p90_hours": ThresholdConfig(warn=24, fail=72, description="Lead time P90"),
            },
            doctor_checks=[
                DoctorCheck(id="git_repo", name="Git Repository", description="Check git repo", critical=True),
                DoctorCheck(id="developer_identity", name="Developer Identity", description="Check developer", critical=True),
            ],
        )

    def _parse_config(self, config: dict[str, Any]) -> PolicyConfig:
        """Parse raw config dict into PolicyConfig."""
        policy = PolicyConfig()
        policy.version = config.get("version", "1.0")

        # Parse sensitive paths
        sensitive = config.get("sensitive_paths", {})
        policy.deny_paths = sensitive.get("deny", [])
        policy.warn_paths = sensitive.get("warn", [])

        # Parse secret scanning
        secret_scan = config.get("secret_scan", {})
        policy.secret_scan_enabled = secret_scan.get("enabled", True)
        policy.secret_baseline_file = secret_scan.get("baseline_file", ".secrets.baseline")
        policy.secret_exclude_paths = secret_scan.get("exclude_paths", [])

        for pattern in secret_scan.get("custom_patterns", []):
            policy.custom_secret_patterns.append(SecretPattern(
                name=pattern.get("name", "Unknown"),
                pattern=pattern.get("pattern", ""),
                severity=pattern.get("severity", "medium"),
            ))

        # Parse thresholds
        thresholds = config.get("thresholds", {})
        for name, values in thresholds.items():
            if isinstance(values, dict):
                policy.thresholds[name] = ThresholdConfig(
                    warn=values.get("warn", 0.5),
                    fail=values.get("fail", 1.0),
                    description=values.get("description", ""),
                )

        # Parse memory sources
        memory = config.get("memory_sources", {})
        for source in memory.get("approved", []):
            policy.approved_memory_sources.append(MemorySource(
                path=source.get("path", ""),
                type=source.get("type", ""),
                description=source.get("description", ""),
            ))
        policy.redact_patterns = memory.get("redact_patterns", [])

        retention = memory.get("retention", {})
        policy.retention_daily_days = retention.get("daily_metrics_days", 90)
        policy.retention_weekly_weeks = retention.get("weekly_reports_weeks", 52)

        # Parse session evidence
        session = config.get("session_evidence", {})
        policy.session_evidence_required = session.get("required_for_implement", True)
        policy.session_evidence_fields = session.get("required_fields", [])
        policy.session_evidence_owner_scoped = session.get("owner_scoped", True)

        # Parse doctor checks
        doctor = config.get("doctor", {})
        for check in doctor.get("checks", []):
            policy.doctor_checks.append(DoctorCheck(
                id=check.get("id", ""),
                name=check.get("name", ""),
                description=check.get("description", ""),
                critical=check.get("critical", False),
            ))

        # Parse metrics configuration
        metrics = config.get("metrics", {})
        collection = metrics.get("collection", {})
        policy.metrics_on_session_start = collection.get("on_session_start", True)
        policy.metrics_on_session_end = collection.get("on_session_end", True)
        policy.metrics_on_verify_loop = collection.get("on_verify_loop", True)
        policy.metrics_on_task_complete = collection.get("on_task_complete", True)

        reports = metrics.get("reports", {})
        policy.metrics_weekly_enabled = reports.get("weekly_enabled", True)
        policy.metrics_output_dir = reports.get("output_dir", ".trellis/metrics/weekly")

        return policy

    def get_threshold(self, name: str) -> ThresholdConfig | None:
        """Get a specific threshold configuration.

        Args:
            name: Threshold name

        Returns:
            ThresholdConfig or None if not found
        """
        policy = self.load()
        return policy.thresholds.get(name)

    def evaluate_threshold(self, name: str, value: float) -> str:
        """Evaluate a value against a threshold.

        Args:
            name: Threshold name
            value: Value to evaluate

        Returns:
            "pass", "warn", or "fail"
        """
        threshold = self.get_threshold(name)
        if threshold is None:
            return "pass"

        if value >= threshold.fail:
            return "fail"
        elif value >= threshold.warn:
            return "warn"
        else:
            return "pass"

    def is_path_denied(self, path: str) -> bool:
        """Check if a path matches deny patterns.

        Args:
            path: Path to check

        Returns:
            True if path is denylisted
        """
        import fnmatch

        policy = self.load()
        path_str = str(path).replace("\\", "/")

        for pattern in policy.deny_paths:
            if fnmatch.fnmatch(path_str, pattern):
                return True
            # Also check just the filename
            if fnmatch.fnmatch(Path(path).name, pattern):
                return True

        return False

    def is_path_warned(self, path: str) -> bool:
        """Check if a path matches warn patterns.

        Args:
            path: Path to check

        Returns:
            True if path should generate a warning
        """
        import fnmatch

        policy = self.load()
        path_str = str(path).replace("\\", "/")

        for pattern in policy.warn_paths:
            if fnmatch.fnmatch(path_str, pattern):
                return True
            if fnmatch.fnmatch(Path(path).name, pattern):
                return True

        return False

    def is_memory_source_approved(self, path: str) -> bool:
        """Check if a path is an approved memory source.

        Args:
            path: Path to check

        Returns:
            True if path is an approved memory source
        """
        policy = self.load()
        path_str = str(path).replace("\\", "/")

        for source in policy.approved_memory_sources:
            if path_str.startswith(source.path) or source.path in path_str:
                return True

        return False

    def validate(self) -> list[str]:
        """Validate policy configuration.

        Returns:
            List of validation errors (empty if valid)
        """
        errors = []

        if not self.policy_file_path.exists():
            errors.append(f"Policy file not found: {self.policy_file_path}")
            return errors

        try:
            policy = self.load()

            # Validate thresholds
            for name, threshold in policy.thresholds.items():
                if threshold.warn < 0:
                    errors.append(f"Threshold '{name}': warn value cannot be negative")
                # Allow fail < warn only if fail is negative (meaning "never fail")
                if threshold.fail < threshold.warn and threshold.fail >= 0:
                    errors.append(f"Threshold '{name}': fail value must be >= warn value (or negative to disable)")

            # Validate retention values
            if policy.retention_daily_days < 1:
                errors.append("Retention daily_days must be >= 1")
            if policy.retention_weekly_weeks < 1:
                errors.append("Retention weekly_weeks must be >= 1")

        except Exception as e:
            errors.append(f"Failed to parse policy: {e}")

        return errors


# =============================================================================
# Convenience Functions
# =============================================================================

def get_policy_loader(repo_root: Path | str | None = None) -> PolicyLoader:
    """Get a policy loader instance.

    Args:
        repo_root: Repository root path. If None, auto-detects.

    Returns:
        PolicyLoader instance
    """
    if repo_root is None:
        # Auto-detect repo root
        from common.paths import get_repo_root
        repo_root = get_repo_root()

    return PolicyLoader(repo_root)


def load_policy(repo_root: Path | str | None = None) -> PolicyConfig:
    """Load policy configuration.

    Args:
        repo_root: Repository root path. If None, auto-detects.

    Returns:
        PolicyConfig instance
    """
    return get_policy_loader(repo_root).load()
