#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Weekly Report Generator - Generate weekly workflow metrics reports.

Aggregates daily metrics and generates a comprehensive Markdown report
with the 6 key indicators defined in the silver-bullet plan.

Usage:
    # Generate report for current week
    python3 generate_report.py

    # Generate report for specific week
    python3 generate_report.py --week 2024-W07

    # Generate report for last N weeks
    python3 generate_report.py --last 4
"""

from __future__ import annotations

import sys
from datetime import date, datetime, timedelta
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
DIR_WEEKLY = "weekly"


# =============================================================================
# Weekly Report Generator
# =============================================================================

class WeeklyReportGenerator:
    """Generate weekly workflow metrics reports."""

    def __init__(self, repo_root: Path):
        """Initialize report generator.

        Args:
            repo_root: Path to repository root
        """
        self.repo_root = repo_root
        self.weekly_dir = repo_root / DIR_WORKFLOW / DIR_METRICS / DIR_WEEKLY

    def ensure_dirs(self) -> None:
        """Ensure weekly reports directory exists."""
        self.weekly_dir.mkdir(parents=True, exist_ok=True)

    def get_week_bounds(self, year: int, week: int) -> tuple[date, date]:
        """Get start and end dates for a week.

        Args:
            year: Year
            week: Week number (1-53)

        Returns:
            Tuple of (start_date, end_date)
        """
        # ISO week starts on Monday
        jan4 = date(year, 1, 4)  # Jan 4 is always in week 1
        week1_monday = jan4 - timedelta(days=jan4.weekday())
        target_monday = week1_monday + timedelta(weeks=week - 1)
        target_sunday = target_monday + timedelta(days=6)
        return target_monday, target_sunday

    def get_current_week(self) -> tuple[int, int]:
        """Get current year and week number.

        Returns:
            Tuple of (year, week_number)
        """
        iso_cal = date.today().isocalendar()
        return iso_cal[0], iso_cal[1]

    def generate_report(self, year: int | None = None, week: int | None = None) -> str:
        """Generate weekly report as Markdown.

        Args:
            year: Year (defaults to current)
            week: Week number (defaults to current)

        Returns:
            Markdown report string
        """
        if year is None or week is None:
            year, week = self.get_current_week()

        start_date, end_date = self.get_week_bounds(year, week)

        # Collect metrics
        try:
            from collect_metrics import MetricsCollector
            collector = MetricsCollector(self.repo_root)
            aggregated = collector.aggregate_range(start_date, end_date)
        except Exception as e:
            aggregated = {"error": str(e)}

        # Generate report
        report = self._build_markdown_report(
            year=year,
            week=week,
            start_date=start_date,
            end_date=end_date,
            metrics=aggregated,
        )

        return report

    def _build_markdown_report(
        self,
        year: int,
        week: int,
        start_date: date,
        end_date: date,
        metrics: dict[str, Any],
    ) -> str:
        """Build Markdown report."""
        lines = []

        # Header
        lines.append(f"# Workflow Weekly Report")
        lines.append(f"")
        lines.append(f"**Week**: {year}-W{week:02d}")
        lines.append(f"**Period**: {start_date.isoformat()} to {end_date.isoformat()}")
        lines.append(f"**Generated**: {datetime.now().isoformat()}")
        lines.append(f"")

        # Executive Summary
        lines.append(f"## Summary")
        lines.append(f"")

        if "error" in metrics:
            lines.append(f"⚠️ Metrics collection error: {metrics['error']}")
        else:
            sessions = metrics.get("sessions_successful", 0) + metrics.get("sessions_failed", 0)
            success_rate = metrics.get("session_success_rate", 1.0)
            tasks = metrics.get("tasks_completed", 0)

            lines.append(f"| Metric | Value |")
            lines.append(f"|--------|-------|")
            lines.append(f"| Sessions | {sessions} |")
            lines.append(f"| Success Rate | {success_rate:.1%} |")
            lines.append(f"| Tasks Completed | {tasks} |")
            lines.append(f"| Verify Loops | {metrics.get('verify_loops', 0)} |")
            lines.append(f"")
        lines.append("")

        # 6 Key Indicators (as defined in silver-bullet plan)
        lines.append(f"## Key Indicators")
        lines.append(f"")
        lines.append(f"| # | Indicator | Value | Status |")
        lines.append(f"|---|-----------|-------|--------|")

        # 1. Lead Time P50/P90
        lead_time = metrics.get("avg_task_duration_hours", 0)
        lead_status = self._get_status(lead_time, 8, 24, lower_is_better=True)
        lines.append(f"| 1 | Lead Time (avg) | {lead_time:.1f}h | {lead_status} |")

        # 2. Verify Failure Rate
        failure_rate = metrics.get("verify_failure_rate", 0)
        fail_status = self._get_status(failure_rate, 0.2, 0.5, lower_is_better=True)
        lines.append(f"| 2 | Verify Failure Rate | {failure_rate:.1%} | {fail_status} |")

        # 3. Rework Count
        rework = metrics.get("rework_events", 0)
        rework_status = self._get_status(rework, 3, 5, lower_is_better=True)
        lines.append(f"| 3 | Rework Events | {rework} | {rework_status} |")

        # 4. Parallel Throughput
        parallel = metrics.get("parallel_tasks_peak", 0)
        # For parallel: higher is better, so thresholds are minimum values
        # warn=1 means "warn if < 1 parallel tasks (no parallelization)"
        # fail=0 means "never fail" (parallelization is optional improvement)
        parallel_status = self._get_status(parallel, 1, 0, lower_is_better=False)
        lines.append(f"| 4 | Parallel Throughput | {parallel} concurrent | {parallel_status} |")

        # 5. Spec Drift Events
        drift = metrics.get("spec_drift_events", 0)
        drift_status = self._get_status(drift, 3, 10, lower_is_better=True)
        lines.append(f"| 5 | Spec Drift Events | {drift} | {drift_status} |")

        # 6. Token Cost (placeholder - depends on platform API)
        lines.append(f"| 6 | Token Cost | N/A | ⚪ N/A |")

        lines.append(f"")

        # Detailed Metrics
        lines.append(f"## Detailed Metrics")
        lines.append(f"")

        lines.append(f"### Sessions")
        lines.append(f"")
        lines.append(f"- Starts: {metrics.get('session_starts', 0)}")
        lines.append(f"- Ends: {metrics.get('session_ends', 0)}")
        lines.append(f"- Successful: {metrics.get('sessions_successful', 0)}")
        lines.append(f"- Failed: {metrics.get('sessions_failed', 0)}")
        lines.append(f"")

        lines.append(f"### Verify Loops")
        lines.append(f"")
        lines.append(f"- Total Loops: {metrics.get('verify_loops', 0)}")
        lines.append(f"- Successes: {metrics.get('verify_successes', 0)}")
        lines.append(f"- Failures: {metrics.get('verify_failures', 0)}")
        lines.append(f"- Total Attempts: {metrics.get('total_verify_attempts', 0)}")
        lines.append(f"")

        lines.append(f"### Tasks")
        lines.append(f"")
        lines.append(f"- Completed: {metrics.get('tasks_completed', 0)}")
        lines.append(f"- Total Duration: {metrics.get('total_task_duration_hours', 0):.1f}h")
        lines.append(f"- Avg Duration: {metrics.get('avg_task_duration_hours', 0):.1f}h")
        lines.append(f"")

        # Recommendations
        lines.append(f"## Recommendations")
        lines.append(f"")

        recommendations = []

        if failure_rate > 0.3:
            recommendations.append("- 🔴 High verify failure rate. Consider improving test coverage or pre-commit checks.")

        if rework > 3:
            recommendations.append("- 🟡 High rework count. Review task planning and acceptance criteria.")

        if drift > 3:
            recommendations.append("- 🟡 Spec drift detected. Ensure specs are updated with code changes.")

        if parallel < 2:
            recommendations.append("- 🟢 Consider using worktrees for parallel task execution.")

        if not recommendations:
            recommendations.append("- ✅ All indicators are within healthy ranges.")

        lines.extend(recommendations)
        lines.append(f"")

        # Footer
        lines.append(f"---")
        lines.append(f"")
        lines.append(f"*Generated by Trellis Workflow Metrics*")

        return "\n".join(lines)

    def _get_status(
        self,
        value: float,
        warn_threshold: float,
        fail_threshold: float,
        lower_is_better: bool = True,
    ) -> str:
        """Get status indicator for a metric value.

        For lower_is_better=True (default):
            - value >= fail_threshold → Fail
            - value >= warn_threshold → Warn
            - else → OK

        For lower_is_better=False (higher is better):
            - value < fail_threshold → Fail (value too low)
            - value < warn_threshold → Warn (value not high enough)
            - else → OK
        """
        if lower_is_better:
            if value >= fail_threshold:
                return "🔴 Fail"
            elif value >= warn_threshold:
                return "🟡 Warn"
            else:
                return "🟢 OK"
        else:
            # Higher is better: fail/warn thresholds are minimum values
            if value < fail_threshold:
                return "🔴 Fail"
            elif value < warn_threshold:
                return "🟡 Warn"
            else:
                return "🟢 OK"

    def save_report(self, report: str, year: int, week: int) -> Path:
        """Save report to file.

        Args:
            report: Markdown report content
            year: Year
            week: Week number

        Returns:
            Path to saved file
        """
        self.ensure_dirs()
        filename = f"report-{year}-W{week:02d}.md"
        file_path = self.weekly_dir / filename

        file_path.write_text(report, encoding="utf-8")
        return file_path

    def print_report(self, year: int | None = None, week: int | None = None) -> None:
        """Print report to stdout."""
        report = self.generate_report(year, week)
        print(report)


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


def parse_week(week_str: str) -> tuple[int, int]:
    """Parse week string like '2024-W07' or 'W07'.

    Returns:
        Tuple of (year, week_number)
    """
    if week_str.startswith("W"):
        # Just week number, use current year
        week_num = int(week_str[1:])
        return date.today().year, week_num
    elif "-W" in week_str:
        # Full format: 2024-W07
        parts = week_str.split("-W")
        return int(parts[0]), int(parts[1])
    else:
        raise ValueError(f"Invalid week format: {week_str}")


def main() -> int:
    """CLI entry point."""
    import argparse

    parser = argparse.ArgumentParser(description="Generate weekly workflow report")
    parser.add_argument("--week", help="Week to report (e.g., 2024-W07 or W07)")
    parser.add_argument("--last", type=int, metavar="N", help="Generate reports for last N weeks")
    parser.add_argument("--save", action="store_true", help="Save report to file")
    parser.add_argument("--output", "-o", help="Output file path")

    args = parser.parse_args()

    repo_root = get_repo_root()
    generator = WeeklyReportGenerator(repo_root)

    if args.last:
        # Generate reports for last N weeks
        current_year, current_week = generator.get_current_week()

        for i in range(args.last):
            # Calculate week
            weeks_ago = args.last - 1 - i
            target_date = date.today() - timedelta(weeks=weeks_ago)
            iso_cal = target_date.isocalendar()
            year, week = iso_cal[0], iso_cal[1]

            report = generator.generate_report(year, week)

            if args.save:
                file_path = generator.save_report(report, year, week)
                print(f"Saved: {file_path}")
            else:
                print(report)
                print("\n" + "=" * 60 + "\n")

    elif args.week:
        # Specific week
        year, week = parse_week(args.week)
        report = generator.generate_report(year, week)

        if args.output:
            Path(args.output).write_text(report, encoding="utf-8")
            print(f"Report saved to: {args.output}")
        elif args.save:
            file_path = generator.save_report(report, year, week)
            print(f"Report saved to: {file_path}")
        else:
            print(report)

    else:
        # Current week
        report = generator.generate_report()

        if args.output:
            Path(args.output).write_text(report, encoding="utf-8")
            print(f"Report saved to: {args.output}")
        elif args.save:
            year, week = generator.get_current_week()
            file_path = generator.save_report(report, year, week)
            print(f"Report saved to: {file_path}")
        else:
            print(report)

    return 0


if __name__ == "__main__":
    sys.exit(main())
