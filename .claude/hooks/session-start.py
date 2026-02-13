#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Session Start Hook - Inject structured context

Also records session-start metric event for observability.
"""

# IMPORTANT: Suppress all warnings FIRST
import warnings
warnings.filterwarnings("ignore")

import json
import os
import subprocess
import sys
from io import StringIO
from pathlib import Path


# =============================================================================
# Metrics Recording
# =============================================================================

def record_session_start_metric(repo_root: Path) -> None:
    """Record session start metric event.

    This is a best-effort operation - failures are silently ignored.
    """
    try:
        metrics_script = repo_root / ".trellis" / "scripts" / "collect_metrics.py"
        if not metrics_script.exists():
            return

        # Get current task if any
        current_task_file = repo_root / ".trellis" / ".current-task"
        task_name = None
        if current_task_file.exists():
            try:
                task_name = current_task_file.read_text(encoding="utf-8").strip()
            except Exception:
                pass

        # Get developer identity
        developer_file = repo_root / ".trellis" / ".developer"
        developer = None
        if developer_file.exists():
            try:
                developer = developer_file.read_text(encoding="utf-8").strip()
            except Exception:
                pass

        # Run metrics collection using uv
        cmd = [
            "uv",
            "run",
            str(metrics_script),
            "session-start",
        ]
        if task_name:
            cmd.extend(["--task", task_name])
        if developer:
            cmd.extend(["--developer", developer])

        subprocess.run(
            cmd,
            capture_output=True,
            timeout=5,
            cwd=repo_root,
        )
    except Exception:
        # Silently ignore metric recording failures
        pass

# IMPORTANT: Force stdout to use UTF-8 on Windows
# This fixes UnicodeEncodeError when outputting non-ASCII characters
if sys.platform == "win32":
    import io as _io
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
    elif hasattr(sys.stdout, "detach"):
        sys.stdout = _io.TextIOWrapper(sys.stdout.detach(), encoding="utf-8", errors="replace")  # type: ignore[union-attr]


def should_skip_injection() -> bool:
    return (
        os.environ.get("CLAUDE_NON_INTERACTIVE") == "1"
        or os.environ.get("OPENCODE_NON_INTERACTIVE") == "1"
    )


def read_file(path: Path, fallback: str = "") -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (FileNotFoundError, PermissionError):
        return fallback


def run_script(script_path: Path) -> str:
    try:
        if script_path.suffix == ".py":
            # Add PYTHONIOENCODING to force UTF-8 in subprocess
            env = os.environ.copy()
            env["PYTHONIOENCODING"] = "utf-8"
            cmd = [sys.executable, "-W", "ignore", str(script_path)]
        else:
            env = os.environ
            cmd = [str(script_path)]

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=5,
            cwd=script_path.parent.parent.parent,
            env=env,
        )
        return result.stdout if result.returncode == 0 else "No context available"
    except (subprocess.TimeoutExpired, FileNotFoundError, PermissionError):
        return "No context available"


def main():
    if should_skip_injection():
        sys.exit(0)

    project_dir = Path(os.environ.get("CLAUDE_PROJECT_DIR", ".")).resolve()
    trellis_dir = project_dir / ".trellis"
    claude_dir = project_dir / ".claude"

    # Record session start metric (best-effort)
    record_session_start_metric(project_dir)

    output = StringIO()

    output.write("""<session-context>
You are starting a new session in a Trellis-managed project.
Read and follow all instructions below carefully.
</session-context>

""")

    output.write("<current-state>\n")
    context_script = trellis_dir / "scripts" / "get_context.py"
    output.write(run_script(context_script))
    output.write("\n</current-state>\n\n")

    output.write("<workflow>\n")
    workflow_content = read_file(trellis_dir / "workflow.md", "No workflow.md found")
    output.write(workflow_content)
    output.write("\n</workflow>\n\n")

    output.write("<guidelines>\n")

    output.write("## Frontend\n")
    frontend_index = read_file(
        trellis_dir / "spec" / "frontend" / "index.md", "Not configured"
    )
    output.write(frontend_index)
    output.write("\n\n")

    output.write("## Backend\n")
    backend_index = read_file(
        trellis_dir / "spec" / "backend" / "index.md", "Not configured"
    )
    output.write(backend_index)
    output.write("\n\n")

    output.write("## Guides\n")
    guides_index = read_file(
        trellis_dir / "spec" / "guides" / "index.md", "Not configured"
    )
    output.write(guides_index)

    output.write("\n</guidelines>\n\n")

    output.write("<instructions>\n")
    start_md = read_file(
        claude_dir / "commands" / "trellis" / "start.md", "No start.md found"
    )
    output.write(start_md)
    output.write("\n</instructions>\n\n")

    output.write("""<ready>
Context loaded. Wait for user's first message, then follow <instructions> to handle their request.
</ready>""")

    result = {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": output.getvalue(),
        }
    }

    # Output JSON - stdout is already configured for UTF-8
    print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
