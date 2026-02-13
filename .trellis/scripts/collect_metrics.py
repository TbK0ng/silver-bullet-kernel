#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Metrics Collector - Collect and store workflow metrics.

Collects metrics from various workflow events and stores them as daily
JSON files for later aggregation and reporting.

Usage:
    # Record a session start event
    python3 collect_metrics.py session-start --task "02-13-my-task"

    # Record a session end event
    python3 collect_metrics.py session-end --task "02-13-my-task" --success

    # Record a verify loop event
    python3 collect_metrics.py verify-loop --task "02-13-my-task" --success --attempts 2

    # Record a task completion
    python3 collect_metrics.py task-complete --task "02-13-my-task" --duration-hours 4.5

    # Aggregate daily metrics
    python3 collect_metrics.py aggregate --date 2024-02-13
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass, asdict
from datetime import datetime, date
from pathlib import Path
from typing import Any

# Handle Windows encoding
if sys.platform == "win32":
    import io as _io
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# =============================================================================
# Constants
# =============================================================================

DIR_WORKFLOW = ".trellis"
DIR_METRICS = "metrics"
DIR_DAILY = "daily"
METRICS_FILE_PREFIX = "metrics-"


# =============================================================================
# Data Classes
# =============================================================================

@dataclass
class MetricEvent:
    """A single metric event."""
    event_type: str
    timestamp: str
    task: str | None = None
    developer: str | None = None
    success: bool = True
    duration_hours: float | None = None
    attempts: int = 1
    phase: str | None = None
    metadata: dict[str, Any] | None = None


@dataclass
class DailyMetrics:
    """Aggregated metrics for a single day."""
    date: str
    session_starts: int = 0
    session_ends: int = 0
    sessions_successful: int = 0
    sessions_failed: int = 0
    verify_loops: int = 0
    verify_successes: int = 0
    verify_failures: int = 0
    total_verify_attempts: int = 0
    tasks_completed: int = 0
    total_task_duration_hours: float = 0.0
    rework_events: int = 0
    spec_drift_events: int = 0
    parallel_tasks_peak: int = 0
    events: list[dict[str, Any]] | None = None

    def to_dict(self) -> dict[str, Any]:
        return {k: v for k, v in asdict(self).items() if v is not None}


# =============================================================================
# Metrics Collector Class
# =============================================================================

class MetricsCollector:
    """Collect and store workflow metrics."""

    def __init__(self, repo_root: Path):
        """Initialize metrics collector.

        Args:
            repo_root: Path to repository root
        """
        self.repo_root = repo_root
        self.metrics_dir = repo_root / DIR_WORKFLOW / DIR_METRICS
        self.daily_dir = self.metrics_dir / DIR_DAILY

    def ensure_dirs(self) -> None:
        """Ensure metrics directories exist."""
        self.daily_dir.mkdir(parents=True, exist_ok=True)

    def get_daily_file_path(self, target_date: date | None = None) -> Path:
        """Get path to daily metrics file.

        Args:
            target_date: Date for the file. Defaults to today.

        Returns:
            Path to daily metrics JSON file
        """
        if target_date is None:
            target_date = date.today()

        filename = f"{METRICS_FILE_PREFIX}{target_date.isoformat()}.json"
        return self.daily_dir / filename

    def load_daily_metrics(self, target_date: date | None = None) -> DailyMetrics:
        """Load daily metrics from file.

        Args:
            target_date: Date to load. Defaults to today.

        Returns:
            DailyMetrics instance
        """
        file_path = self.get_daily_file_path(target_date)

        if file_path.exists():
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                return DailyMetrics(**data)
            except Exception:
                pass

        # Return empty metrics for the date
        target_date = target_date or date.today()
        return DailyMetrics(date=target_date.isoformat())

    def save_daily_metrics(self, metrics: DailyMetrics, target_date: date | None = None) -> None:
        """Save daily metrics to file.

        Args:
            metrics: DailyMetrics to save
            target_date: Date for the file. Defaults to today.
        """
        self.ensure_dirs()
        file_path = self.get_daily_file_path(target_date)

        with open(file_path, "w", encoding="utf-8") as f:
            json.dump(metrics.to_dict(), f, indent=2, ensure_ascii=False)

    def record_event(self, event: MetricEvent) -> None:
        """Record a metric event.

        Args:
            event: MetricEvent to record
        """
        # Parse date from timestamp
        event_date = datetime.fromisoformat(event.timestamp).date()
        metrics = self.load_daily_metrics(event_date)

        # Update counters based on event type
        if event.event_type == "session-start":
            metrics.session_starts += 1

        elif event.event_type == "session-end":
            metrics.session_ends += 1
            if event.success:
                metrics.sessions_successful += 1
            else:
                metrics.sessions_failed += 1

        elif event.event_type == "verify-loop":
            metrics.verify_loops += 1
            metrics.total_verify_attempts += event.attempts
            if event.success:
                metrics.verify_successes += 1
            else:
                metrics.verify_failures += 1

        elif event.event_type == "task-complete":
            metrics.tasks_completed += 1
            if event.duration_hours:
                metrics.total_task_duration_hours += event.duration_hours

        elif event.event_type == "rework":
            metrics.rework_events += 1

        elif event.event_type == "spec-drift":
            metrics.spec_drift_events += 1

        elif event.event_type == "parallel-peak":
            metrics.parallel_tasks_peak = max(metrics.parallel_tasks_peak, event.attempts)

        # Store raw event for detailed analysis
        if metrics.events is None:
            metrics.events = []
        metrics.events.append(asdict(event))

        self.save_daily_metrics(metrics, event_date)

    def get_metrics_range(self, start_date: date, end_date: date) -> list[DailyMetrics]:
        """Get metrics for a date range.

        Args:
            start_date: Start date (inclusive)
            end_date: End date (inclusive)

        Returns:
            List of DailyMetrics for the range
        """
        metrics_list = []
        current = start_date

        while current <= end_date:
            metrics = self.load_daily_metrics(current)
            metrics_list.append(metrics)
            # Move to next day
            from datetime import timedelta
            current = current + timedelta(days=1)

        return metrics_list

    def aggregate_range(self, start_date: date, end_date: date) -> dict[str, Any]:
        """Aggregate metrics for a date range.

        Args:
            start_date: Start date (inclusive)
            end_date: End date (inclusive)

        Returns:
            Aggregated metrics dictionary
        """
        metrics_list = self.get_metrics_range(start_date, end_date)

        total = {
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "days": len(metrics_list),
            "session_starts": 0,
            "session_ends": 0,
            "sessions_successful": 0,
            "sessions_failed": 0,
            "verify_loops": 0,
            "verify_successes": 0,
            "verify_failures": 0,
            "total_verify_attempts": 0,
            "tasks_completed": 0,
            "total_task_duration_hours": 0.0,
            "rework_events": 0,
            "spec_drift_events": 0,
            "parallel_tasks_peak": 0,
        }

        for m in metrics_list:
            total["session_starts"] += m.session_starts
            total["session_ends"] += m.session_ends
            total["sessions_successful"] += m.sessions_successful
            total["sessions_failed"] += m.sessions_failed
            total["verify_loops"] += m.verify_loops
            total["verify_successes"] += m.verify_successes
            total["verify_failures"] += m.verify_failures
            total["total_verify_attempts"] += m.total_verify_attempts
            total["tasks_completed"] += m.tasks_completed
            total["total_task_duration_hours"] += m.total_task_duration_hours
            total["rework_events"] += m.rework_events
            total["spec_drift_events"] += m.spec_drift_events
            total["parallel_tasks_peak"] = max(total["parallel_tasks_peak"], m.parallel_tasks_peak)

        # Calculate derived metrics
        total_sessions = total["sessions_successful"] + total["sessions_failed"]
        if total_sessions > 0:
            total["session_success_rate"] = total["sessions_successful"] / total_sessions
        else:
            total["session_success_rate"] = 1.0

        if total["verify_loops"] > 0:
            total["verify_failure_rate"] = total["verify_failures"] / total["verify_loops"]
        else:
            total["verify_failure_rate"] = 0.0

        if total["tasks_completed"] > 0:
            total["avg_task_duration_hours"] = total["total_task_duration_hours"] / total["tasks_completed"]
        else:
            total["avg_task_duration_hours"] = 0.0

        return total


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

    parser = argparse.ArgumentParser(description="Collect workflow metrics")
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # session-start
    p_start = subparsers.add_parser("session-start", help="Record session start")
    p_start.add_argument("--task", help="Task name")
    p_start.add_argument("--developer", help="Developer name")

    # session-end
    p_end = subparsers.add_parser("session-end", help="Record session end")
    p_end.add_argument("--task", help="Task name")
    p_end.add_argument("--developer", help="Developer name")
    p_end.add_argument("--success", action="store_true", help="Session successful")
    p_end.add_argument("--fail", dest="success", action="store_false", help="Session failed")

    # verify-loop
    p_verify = subparsers.add_parser("verify-loop", help="Record verify loop")
    p_verify.add_argument("--task", help="Task name")
    p_verify.add_argument("--attempts", type=int, default=1, help="Number of attempts")
    p_verify.add_argument("--success", action="store_true", help="Verify passed")
    p_verify.add_argument("--fail", dest="success", action="store_false", help="Verify failed")

    # task-complete
    p_task = subparsers.add_parser("task-complete", help="Record task completion")
    p_task.add_argument("--task", required=True, help="Task name")
    p_task.add_argument("--duration-hours", type=float, help="Task duration in hours")

    # rework
    p_rework = subparsers.add_parser("rework", help="Record rework event")
    p_rework.add_argument("--task", required=True, help="Task name")
    p_rework.add_argument("--phase", help="Phase that triggered rework")

    # spec-drift
    p_drift = subparsers.add_parser("spec-drift", help="Record spec drift event")
    p_drift.add_argument("--file", help="File that drifted from spec")

    # aggregate
    p_agg = subparsers.add_parser("aggregate", help="Aggregate daily metrics")
    p_agg.add_argument("--date", help="Date to aggregate (YYYY-MM-DD)")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    repo_root = get_repo_root()
    collector = MetricsCollector(repo_root)

    if args.command == "session-start":
        event = MetricEvent(
            event_type="session-start",
            timestamp=datetime.now().isoformat(),
            task=getattr(args, "task", None),
            developer=getattr(args, "developer", None),
        )
        collector.record_event(event)
        print(f"Recorded session-start event")

    elif args.command == "session-end":
        event = MetricEvent(
            event_type="session-end",
            timestamp=datetime.now().isoformat(),
            task=getattr(args, "task", None),
            developer=getattr(args, "developer", None),
            success=args.success,
        )
        collector.record_event(event)
        print(f"Recorded session-end event (success={args.success})")

    elif args.command == "verify-loop":
        event = MetricEvent(
            event_type="verify-loop",
            timestamp=datetime.now().isoformat(),
            task=getattr(args, "task", None),
            success=args.success,
            attempts=args.attempts,
        )
        collector.record_event(event)
        print(f"Recorded verify-loop event (attempts={args.attempts}, success={args.success})")

    elif args.command == "task-complete":
        event = MetricEvent(
            event_type="task-complete",
            timestamp=datetime.now().isoformat(),
            task=args.task,
            duration_hours=args.duration_hours,
        )
        collector.record_event(event)
        print(f"Recorded task-complete event for {args.task}")

    elif args.command == "rework":
        event = MetricEvent(
            event_type="rework",
            timestamp=datetime.now().isoformat(),
            task=args.task,
            phase=getattr(args, "phase", None),
        )
        collector.record_event(event)
        print(f"Recorded rework event for {args.task}")

    elif args.command == "spec-drift":
        event = MetricEvent(
            event_type="spec-drift",
            timestamp=datetime.now().isoformat(),
            metadata={"file": getattr(args, "file", None)},
        )
        collector.record_event(event)
        print(f"Recorded spec-drift event")

    elif args.command == "aggregate":
        if args.date:
            target_date = date.fromisoformat(args.date)
        else:
            target_date = date.today()

        metrics = collector.load_daily_metrics(target_date)
        print(json.dumps(metrics.to_dict(), indent=2))

    return 0


if __name__ == "__main__":
    sys.exit(main())
