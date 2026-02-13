import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { afterEach, describe, expect, it } from "vitest";

function run(command: string, args: string[], cwd: string) {
  return spawnSync(command, args, {
    cwd,
    encoding: "utf8",
  });
}

function writeFile(targetPath: string, content: string) {
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  fs.writeFileSync(targetPath, content, "utf8");
}

describe("memory context progressive disclosure", () => {
  const tempDirs: string[] = [];

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
    tempDirs.length = 0;
  });

  it("supports index and detail stages with audit output", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-memory-context-"));
    tempDirs.push(repoDir);

    writeFile(
      path.join(repoDir, "scripts", "memory-context.ps1"),
      fs.readFileSync(path.join(process.cwd(), "scripts", "memory-context.ps1"), "utf8"),
    );
    writeFile(
      path.join(repoDir, "workflow-policy.json"),
      fs.readFileSync(path.join(process.cwd(), "workflow-policy.json"), "utf8"),
    );

    writeFile(path.join(repoDir, ".trellis", "spec", "guides", "constitution.md"), "# Constitution");
    writeFile(path.join(repoDir, ".trellis", "spec", "guides", "memory-governance.md"), "# Memory Governance");
    writeFile(path.join(repoDir, ".trellis", "spec", "guides", "quality-gates.md"), "# Quality Gates");
    writeFile(path.join(repoDir, ".trellis", "workflow.md"), "# Workflow");
    writeFile(path.join(repoDir, "xxx_docs", "README.md"), "# Docs Home");
    writeFile(path.join(repoDir, "README.md"), "# Repo Readme");
    writeFile(path.join(repoDir, "AGENTS.md"), "# Agents");
    writeFile(path.join(repoDir, ".trellis", "workspace", "codex", "index.md"), "# Codex Index");
    writeFile(path.join(repoDir, ".trellis", "workspace", "codex", "journal-1.md"), "## Session 1");

    writeFile(path.join(repoDir, "openspec", "changes", "sample-change", "proposal.md"), "proposal");
    writeFile(path.join(repoDir, "openspec", "changes", "sample-change", "design.md"), "design");
    writeFile(path.join(repoDir, "openspec", "changes", "sample-change", "tasks.md"), "tasks");
    writeFile(
      path.join(repoDir, "openspec", "changes", "sample-change", "specs", "sample-capability", "spec.md"),
      "## ADDED Requirements\n\n### Requirement: sample\n\n- test",
    );

    run("git", ["init"], repoDir);
    run("git", ["config", "user.email", "test@example.com"], repoDir);
    run("git", ["config", "user.name", "sbk-test"], repoDir);
    run("git", ["add", "."], repoDir);
    run("git", ["commit", "-m", "init"], repoDir);
    run("git", ["checkout", "-b", "sbk-codex-sample-change"], repoDir);

    const pwsh = process.platform === "win32" ? "powershell.exe" : "pwsh";
    const indexRun = run(
      pwsh,
      [
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "./scripts/memory-context.ps1",
        "-Stage",
        "index",
        "-Change",
        "sample-change",
      ],
      repoDir,
    );
    expect(indexRun.status).toBe(0);
    const indexPayload = JSON.parse(indexRun.stdout);
    expect(indexPayload.stage).toBe("index");
    expect(indexPayload.count).toBeGreaterThan(0);
    expect(indexPayload.sources[0].id).toMatch(/^S\d{3}$/);

    const firstId = indexPayload.sources[0].id as string;
    const detailRun = run(
      pwsh,
      [
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "./scripts/memory-context.ps1",
        "-Stage",
        "detail",
        "-Change",
        "sample-change",
        "-Ids",
        firstId,
      ],
      repoDir,
    );
    expect(detailRun.status).toBe(0);
    const detailPayload = JSON.parse(detailRun.stdout);
    expect(detailPayload.stage).toBe("detail");
    expect(detailPayload.count).toBe(1);
    expect(typeof detailPayload.sources[0].excerpt).toBe("string");

    const auditPath = path.join(repoDir, ".metrics", "memory-context-audit.jsonl");
    expect(fs.existsSync(auditPath)).toBe(true);
    const auditLines = fs
      .readFileSync(auditPath, "utf8")
      .split(/\r?\n/)
      .filter((line) => line.trim().length > 0);
    expect(auditLines.length).toBeGreaterThanOrEqual(2);
  }, 30000);

  it("supports index stage on non-sbk branches without explicit change", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-memory-context-default-"));
    tempDirs.push(repoDir);

    writeFile(
      path.join(repoDir, "scripts", "memory-context.ps1"),
      fs.readFileSync(path.join(process.cwd(), "scripts", "memory-context.ps1"), "utf8"),
    );
    writeFile(
      path.join(repoDir, "workflow-policy.json"),
      fs.readFileSync(path.join(process.cwd(), "workflow-policy.json"), "utf8"),
    );

    writeFile(path.join(repoDir, ".trellis", "spec", "guides", "constitution.md"), "# Constitution");
    writeFile(path.join(repoDir, ".trellis", "spec", "guides", "memory-governance.md"), "# Memory Governance");
    writeFile(path.join(repoDir, ".trellis", "spec", "guides", "quality-gates.md"), "# Quality Gates");
    writeFile(path.join(repoDir, ".trellis", "workflow.md"), "# Workflow");
    writeFile(path.join(repoDir, "xxx_docs", "README.md"), "# Docs Home");
    writeFile(path.join(repoDir, "README.md"), "# Repo Readme");
    writeFile(path.join(repoDir, "AGENTS.md"), "# Agents");

    run("git", ["init"], repoDir);
    run("git", ["config", "user.email", "test@example.com"], repoDir);
    run("git", ["config", "user.name", "sbk-test"], repoDir);
    run("git", ["add", "."], repoDir);
    run("git", ["commit", "-m", "init"], repoDir);

    const pwsh = process.platform === "win32" ? "powershell.exe" : "pwsh";
    const indexRun = run(
      pwsh,
      ["-ExecutionPolicy", "Bypass", "-File", "./scripts/memory-context.ps1", "-Stage", "index"],
      repoDir,
    );

    expect(indexRun.status).toBe(0);
    const payload = JSON.parse(indexRun.stdout);
    expect(payload.stage).toBe("index");
    expect(payload.branch).not.toMatch(/^sbk-/);
    expect(payload.count).toBeGreaterThan(0);
    expect(payload.sources[0].id).toMatch(/^S\d{3}$/);
  });
});
