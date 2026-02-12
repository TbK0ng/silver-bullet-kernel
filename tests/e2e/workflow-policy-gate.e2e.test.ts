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

describe("workflow policy gate task evidence schema", () => {
  const tempDirs: string[] = [];

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
    tempDirs.length = 0;
  });

  it("fails when active change tasks.md misses required evidence columns", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-policy-gate-"));
    tempDirs.push(repoDir);

    const policyScriptSource = path.join(process.cwd(), "scripts", "workflow-policy-gate.ps1");
    const policyConfigSource = path.join(process.cwd(), "workflow-policy.json");

    writeFile(
      path.join(repoDir, "scripts", "workflow-policy-gate.ps1"),
      fs.readFileSync(policyScriptSource, "utf8"),
    );
    writeFile(
      path.join(repoDir, "workflow-policy.json"),
      fs.readFileSync(policyConfigSource, "utf8"),
    );

    writeFile(
      path.join(repoDir, "openspec", "changes", "sample-change", "proposal.md"),
      "proposal",
    );
    writeFile(
      path.join(repoDir, "openspec", "changes", "sample-change", "design.md"),
      "design",
    );
    writeFile(
      path.join(repoDir, "openspec", "changes", "sample-change", "tasks.md"),
      [
        "## tasks",
        "- missing evidence schema",
      ].join("\n"),
    );
    writeFile(
      path.join(
        repoDir,
        "openspec",
        "changes",
        "sample-change",
        "specs",
        "sample-capability",
        "spec.md",
      ),
      "## ADDED Requirements\n\n### Requirement: sample\n\n- test",
    );

    run("git", ["init"], repoDir);
    run("git", ["config", "user.email", "test@example.com"], repoDir);
    run("git", ["config", "user.name", "sbk-test"], repoDir);
    run("git", ["add", "."], repoDir);
    run("git", ["commit", "-m", "init"], repoDir);
    run("git", ["checkout", "-b", "sbk-codex-sample-change"], repoDir);

    const pwsh = process.platform === "win32" ? "powershell.exe" : "pwsh";
    const gate = run(
      pwsh,
      [
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "./scripts/workflow-policy-gate.ps1",
        "-Mode",
        "local",
      ],
      repoDir,
    );
    expect(gate.status).not.toBe(0);

    const reportPath = path.join(repoDir, "xxx_docs", "generated", "workflow-policy-gate.json");
    expect(fs.existsSync(reportPath)).toBe(true);
    const reportRaw = fs.readFileSync(reportPath, "utf8").replace(/^\uFEFF/, "");
    const report = JSON.parse(reportRaw);
    const schemaCheck = report.checks.find((c: { name: string }) =>
      c.name.includes("tasks evidence schema"),
    );
    expect(schemaCheck).toBeTruthy();
    expect(schemaCheck.passed).toBe(false);
  });
});
