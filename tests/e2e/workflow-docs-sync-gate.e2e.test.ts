import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { afterEach, describe, expect, it } from "vitest";

function run(command: string, args: string[], cwd: string) {
  const env = { ...process.env };
  delete env.WORKFLOW_BASE_REF;
  delete env.GITHUB_BASE_REF;

  return spawnSync(command, args, {
    cwd,
    encoding: "utf8",
    env,
  });
}

function writeFile(targetPath: string, content: string) {
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  fs.writeFileSync(targetPath, content, "utf8");
}

function initGitRepo(repoDir: string) {
  run("git", ["init"], repoDir);
  run("git", ["config", "user.email", "test@example.com"], repoDir);
  run("git", ["config", "user.name", "sbk-test"], repoDir);
  run("git", ["add", "."], repoDir);
  run("git", ["commit", "-m", "init"], repoDir);
  run("git", ["checkout", "-b", "sbk-codex-docs-sync"], repoDir);
}

function bootstrapDocsSyncRepo(repoDir: string) {
  const gateSource = path.join(process.cwd(), "scripts", "workflow-docs-sync-gate.ps1");
  const runtimeSource = path.join(process.cwd(), "scripts", "common", "sbk-runtime.ps1");
  const runtimeConfigSource = path.join(process.cwd(), "sbk.config.json");

  writeFile(
    path.join(repoDir, "scripts", "workflow-docs-sync-gate.ps1"),
    fs.readFileSync(gateSource, "utf8"),
  );
  writeFile(
    path.join(repoDir, "scripts", "common", "sbk-runtime.ps1"),
    fs.readFileSync(runtimeSource, "utf8"),
  );
  writeFile(
    path.join(repoDir, "sbk.config.json"),
    fs.readFileSync(runtimeConfigSource, "utf8"),
  );

  writeFile(path.join(repoDir, "scripts", "verify-fast.ps1"), "Write-Host 'x'\n");
  writeFile(path.join(repoDir, "docs", "02-功能手册-命令原理与产物.md"), "doc2\n");
  writeFile(path.join(repoDir, "docs", "05-命令与产物速查表.md"), "doc5\n");
  writeFile(path.join(repoDir, "docs", "06-多项目类型接入与配置指南.md"), "doc6\n");
}

describe("workflow docs sync gate", () => {
  const tempDirs: string[] = [];

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
    tempDirs.length = 0;
  });

  it("fails when runtime trigger files change without docs updates", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-docs-sync-fail-"));
    tempDirs.push(repoDir);

    bootstrapDocsSyncRepo(repoDir);
    initGitRepo(repoDir);

    writeFile(path.join(repoDir, "scripts", "verify-fast.ps1"), "Write-Host 'changed'\n");

    const pwsh = process.platform === "win32" ? "powershell.exe" : "pwsh";
    const gate = run(
      pwsh,
      [
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "./scripts/workflow-docs-sync-gate.ps1",
        "-Mode",
        "local",
      ],
      repoDir,
    );

    expect(gate.status).not.toBe(0);
    const reportPath = path.join(repoDir, ".metrics", "workflow-docs-sync-gate.json");
    expect(fs.existsSync(reportPath)).toBe(true);
    const report = JSON.parse(fs.readFileSync(reportPath, "utf8").replace(/^\uFEFF/, ""));
    expect(report.passed).toBe(false);
  });

  it("passes when docs are updated together with runtime trigger files", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-docs-sync-pass-"));
    tempDirs.push(repoDir);

    bootstrapDocsSyncRepo(repoDir);
    initGitRepo(repoDir);

    writeFile(path.join(repoDir, "scripts", "verify-fast.ps1"), "Write-Host 'changed'\n");
    writeFile(path.join(repoDir, "docs", "06-多项目类型接入与配置指南.md"), "doc6 changed\n");

    const pwsh = process.platform === "win32" ? "powershell.exe" : "pwsh";
    const gate = run(
      pwsh,
      [
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "./scripts/workflow-docs-sync-gate.ps1",
        "-Mode",
        "local",
      ],
      repoDir,
    );

    expect(gate.status).toBe(0);
    const reportPath = path.join(repoDir, ".metrics", "workflow-docs-sync-gate.json");
    expect(fs.existsSync(reportPath)).toBe(true);
    const report = JSON.parse(fs.readFileSync(reportPath, "utf8").replace(/^\uFEFF/, ""));
    expect(report.passed).toBe(true);
    expect(Array.isArray(report.docsHits)).toBe(true);
    expect(report.docsHits).toContain("docs/06-多项目类型接入与配置指南.md");
  });
});
