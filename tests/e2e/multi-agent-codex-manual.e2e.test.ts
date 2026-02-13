import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { afterEach, describe, expect, it } from "vitest";

function run(command: string, args: string[], cwd: string) {
  return spawnSync(command, args, {
    cwd,
    encoding: "utf8",
    env: { ...process.env },
  });
}

function writeFile(targetPath: string, content: string) {
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  fs.writeFileSync(targetPath, content, "utf8");
}

function copyDir(src: string, dest: string) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDir(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

function initGitRepo(repoDir: string) {
  run("git", ["init"], repoDir);
  run("git", ["config", "user.email", "test@example.com"], repoDir);
  run("git", ["config", "user.name", "sbk-test"], repoDir);
  run("git", ["add", "."], repoDir);
  run("git", ["commit", "-m", "init"], repoDir);
}

function resolvePythonRunner(): { command: string; prefixArgs: string[] } | null {
  const candidates = process.platform === "win32"
    ? [
        { command: "python", prefixArgs: [] as string[] },
        { command: "py", prefixArgs: ["-3"] },
      ]
    : [
        { command: "python3", prefixArgs: [] as string[] },
        { command: "python", prefixArgs: [] as string[] },
      ];

  for (const candidate of candidates) {
    const probe = run(candidate.command, [...candidate.prefixArgs, "--version"], process.cwd());
    if (probe.status === 0) {
      return candidate;
    }
  }

  return null;
}

function bootstrapMultiAgentRepo(repoDir: string) {
  const sourceRoot = process.cwd();

  copyDir(
    path.join(sourceRoot, ".trellis", "scripts", "common"),
    path.join(repoDir, ".trellis", "scripts", "common"),
  );
  writeFile(
    path.join(repoDir, ".trellis", "scripts", "__init__.py"),
    "",
  );
  writeFile(
    path.join(repoDir, ".trellis", "scripts", "multi_agent", "__init__.py"),
    "",
  );
  writeFile(
    path.join(repoDir, ".trellis", "scripts", "multi_agent", "start.py"),
    fs.readFileSync(
      path.join(sourceRoot, ".trellis", "scripts", "multi_agent", "start.py"),
      "utf8",
    ),
  );
  writeFile(
    path.join(repoDir, ".trellis", "scripts", "multi_agent", "plan.py"),
    fs.readFileSync(
      path.join(sourceRoot, ".trellis", "scripts", "multi_agent", "plan.py"),
      "utf8",
    ),
  );

  writeFile(path.join(repoDir, ".trellis", ".developer"), "name=codex\n");
  writeFile(
    path.join(repoDir, ".trellis", "worktree.yaml"),
    [
      "worktree_dir: ./worktrees",
      "copy:",
      "  - .trellis/.developer",
      "post_create:",
    ].join("\n") + "\n",
  );
  writeFile(
    path.join(repoDir, ".agents", "skills", "start", "SKILL.md"),
    "# start\n",
  );

  const taskDir = path.join(repoDir, ".trellis", "tasks", "01-codex-manual");
  writeFile(path.join(taskDir, "prd.md"), "# task\n");
  writeFile(
    path.join(taskDir, "task.json"),
    JSON.stringify(
      {
        id: "01-codex-manual",
        name: "codex manual start",
        status: "planning",
        branch: "sbk-codex-codex-manual",
        next_action: [],
      },
      null,
      2,
    ),
  );
}

describe("multi-agent start codex manual mode", () => {
  const tempDirs: string[] = [];

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
    tempDirs.length = 0;
  });

  it("prepares worktree and registry without starting background process", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-codex-manual-"));
    tempDirs.push(repoDir);

    bootstrapMultiAgentRepo(repoDir);
    initGitRepo(repoDir);

    const pythonRunner = resolvePythonRunner();
    if (!pythonRunner) {
      // Some Windows runners do not include python/py launchers.
      expect(true).toBe(true);
      return;
    }
    const startResult = run(
      pythonRunner.command,
      [
        ...pythonRunner.prefixArgs,
        ".trellis/scripts/multi_agent/start.py",
        ".trellis/tasks/01-codex-manual",
        "--platform",
        "codex",
      ],
      repoDir,
    );

    expect(startResult.status).toBe(0);

    const worktreePath = path.join(repoDir, "worktrees", "sbk-codex-codex-manual");
    const sessionPath = path.join(worktreePath, ".session-id");
    expect(fs.existsSync(sessionPath)).toBe(true);
    expect(fs.readFileSync(sessionPath, "utf8").trim()).toBe("manual");

    const registryPath = path.join(
      repoDir,
      ".trellis",
      "workspace",
      "codex",
      ".agents",
      "registry.json",
    );
    expect(fs.existsSync(registryPath)).toBe(true);
    const registry = JSON.parse(fs.readFileSync(registryPath, "utf8"));
    expect(Array.isArray(registry.agents)).toBe(true);
    expect(registry.agents.length).toBe(1);
    expect(registry.agents[0].platform).toBe("codex");
    expect(registry.agents[0].pid).toBe(0);
  });

  it("exposes codex in multi-agent plan platform options", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-plan-codex-"));
    tempDirs.push(repoDir);

    bootstrapMultiAgentRepo(repoDir);

    const pythonRunner = resolvePythonRunner();
    if (!pythonRunner) {
      expect(true).toBe(true);
      return;
    }

    const planHelp = run(
      pythonRunner.command,
      [
        ...pythonRunner.prefixArgs,
        ".trellis/scripts/multi_agent/plan.py",
        "--help",
      ],
      repoDir,
    );

    expect(planHelp.status).toBe(0);
    expect(planHelp.stdout).toContain("codex");
  });
});
