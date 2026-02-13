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

function ensureDir(targetPath: string) {
  fs.mkdirSync(targetPath, { recursive: true });
}

function bootstrapParityRepo(repoDir: string) {
  const gateSource = path.join(process.cwd(), "scripts", "workflow-skill-parity-gate.ps1");
  writeFile(
    path.join(repoDir, "scripts", "workflow-skill-parity-gate.ps1"),
    fs.readFileSync(gateSource, "utf8"),
  );
}

describe("workflow skill parity gate", () => {
  const tempDirs: string[] = [];

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
    tempDirs.length = 0;
  });

  it("fails when .agents/.claude skill mirrors are incomplete", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-skill-parity-fail-"));
    tempDirs.push(repoDir);

    bootstrapParityRepo(repoDir);

    ensureDir(path.join(repoDir, ".codex", "skills", "memory-context"));
    ensureDir(path.join(repoDir, ".codex", "skills", "semantic-rename"));
    ensureDir(path.join(repoDir, ".codex", "skills", "openspec-apply-change"));

    ensureDir(path.join(repoDir, ".agents", "skills", "memory-context"));
    ensureDir(path.join(repoDir, ".claude", "skills", "memory-context"));
    ensureDir(path.join(repoDir, ".claude", "commands", "trellis"));
    ensureDir(path.join(repoDir, ".claude", "commands", "opsx"));
    writeFile(path.join(repoDir, ".claude", "commands", "trellis", "memory-context.md"), "# cmd\n");
    writeFile(path.join(repoDir, ".claude", "commands", "opsx", "apply.md"), "# cmd\n");

    const pwsh = process.platform === "win32" ? "powershell.exe" : "pwsh";
    const gate = run(
      pwsh,
      ["-ExecutionPolicy", "Bypass", "-File", "./scripts/workflow-skill-parity-gate.ps1"],
      repoDir,
    );

    expect(gate.status).not.toBe(0);
    const reportPath = path.join(repoDir, ".metrics", "workflow-skill-parity-gate.json");
    expect(fs.existsSync(reportPath)).toBe(true);
    const report = JSON.parse(fs.readFileSync(reportPath, "utf8").replace(/^\uFEFF/, ""));
    expect(report.passed).toBe(false);
    expect(report.checks.codexSkillsMirroredToAgents.passed).toBe(false);
  });

  it("passes when codex/agents/claude capability sets are aligned", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-skill-parity-pass-"));
    tempDirs.push(repoDir);

    bootstrapParityRepo(repoDir);

    const codexSkills = [
      "memory-context",
      "parallel",
      "semantic-rename",
      "openspec-apply-change",
    ];
    for (const skill of codexSkills) {
      ensureDir(path.join(repoDir, ".codex", "skills", skill));
      ensureDir(path.join(repoDir, ".agents", "skills", skill));
      ensureDir(path.join(repoDir, ".claude", "skills", skill));
    }

    ensureDir(path.join(repoDir, ".claude", "commands", "trellis"));
    ensureDir(path.join(repoDir, ".claude", "commands", "opsx"));
    writeFile(path.join(repoDir, ".claude", "commands", "trellis", "memory-context.md"), "# cmd\n");
    writeFile(path.join(repoDir, ".claude", "commands", "trellis", "parallel.md"), "# cmd\n");
    writeFile(path.join(repoDir, ".claude", "commands", "trellis", "semantic-rename.md"), "# cmd\n");
    writeFile(path.join(repoDir, ".claude", "commands", "opsx", "apply.md"), "# cmd\n");

    const pwsh = process.platform === "win32" ? "powershell.exe" : "pwsh";
    const gate = run(
      pwsh,
      ["-ExecutionPolicy", "Bypass", "-File", "./scripts/workflow-skill-parity-gate.ps1"],
      repoDir,
    );

    expect(gate.status).toBe(0);
    const reportPath = path.join(repoDir, ".metrics", "workflow-skill-parity-gate.json");
    expect(fs.existsSync(reportPath)).toBe(true);
    const report = JSON.parse(fs.readFileSync(reportPath, "utf8").replace(/^\uFEFF/, ""));
    expect(report.passed).toBe(true);
  });
});
