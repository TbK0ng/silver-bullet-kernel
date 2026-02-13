import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { afterEach, describe, expect, it } from "vitest";

function run(command: string, args: string[], cwd: string) {
  const env = { ...process.env };
  // Keep test repos isolated from caller-level CI base-ref settings.
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

function readJsonReport(repoDir: string) {
  const reportPath = path.join(repoDir, ".metrics", "workflow-policy-gate.json");
  expect(fs.existsSync(reportPath)).toBe(true);
  const reportRaw = fs.readFileSync(reportPath, "utf8").replace(/^\uFEFF/, "");
  return JSON.parse(reportRaw);
}

function bootstrapPolicyRepo(repoDir: string) {
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
    path.join(repoDir, ".claude", "agents", "dispatch.md"),
    [
      "---",
      "name: dispatch",
      "tools: Read, Bash",
      "---",
      "# Dispatch",
    ].join("\n"),
  );
}

function writeValidActiveChange(repoDir: string) {
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
      "## 1. Sample Section",
      "",
      "### Task Evidence",
      "",
      "| ID | Status | Files | Action | Verify | Done |",
      "| --- | --- | --- | --- | --- | --- |",
      "| 1.1 | [ ] | `src/app.ts` | add sample change | `npm run verify:fast` | policy gate passes schema checks |",
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
}

function initGitRepo(repoDir: string) {
  run("git", ["init"], repoDir);
  run("git", ["config", "user.email", "test@example.com"], repoDir);
  run("git", ["config", "user.name", "sbk-test"], repoDir);
  run("git", ["add", "."], repoDir);
  run("git", ["commit", "-m", "init"], repoDir);
  run("git", ["checkout", "-b", "sbk-codex-sample-change"], repoDir);
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

    bootstrapPolicyRepo(repoDir);

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

    initGitRepo(repoDir);

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

    const report = readJsonReport(repoDir);
    const schemaCheck = report.checks.find((c: { name: string }) =>
      c.name.includes("tasks evidence schema"),
    );
    expect(schemaCheck).toBeTruthy();
    expect(schemaCheck.passed).toBe(false);
  });

  it("fails when required task evidence heading is missing", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-policy-heading-"));
    tempDirs.push(repoDir);

    bootstrapPolicyRepo(repoDir);

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
        "## 1. Sample Section",
        "",
        "### Wrong Heading",
        "",
        "| ID | Status | Files | Action | Verify | Done |",
        "| --- | --- | --- | --- | --- | --- |",
        "| 1.1 | [ ] | `src/app.ts` | change | `npm run verify:fast` | done |",
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

    initGitRepo(repoDir);

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

    const report = readJsonReport(repoDir);
    const schemaCheck = report.checks.find((c: { name: string }) =>
      c.name.includes("tasks evidence schema"),
    );
    expect(schemaCheck).toBeTruthy();
    expect(schemaCheck.passed).toBe(false);
    expect(String(schemaCheck.details)).toContain("required_heading=Task Evidence");
  });

  it("fails when secret-like token appears in durable artifacts", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-policy-secret-"));
    tempDirs.push(repoDir);

    bootstrapPolicyRepo(repoDir);
    writeValidActiveChange(repoDir);
    writeFile(
      path.join(repoDir, ".trellis", "workspace", "codex", "journal-1.md"),
      [
        "## Session 1",
        "",
        "Memory Sources",
        "Disclosure Level: index",
        "Source IDs: S001",
      ].join("\n"),
    );

    initGitRepo(repoDir);

    writeFile(
      path.join(repoDir, ".trellis", "workspace", "codex", "journal-1.md"),
      [
        "## Session 1",
        "",
        "Memory Sources",
        "Disclosure Level: index",
        "Source IDs: S001",
        "",
        "Leaked token example: AKIA1234567890ABCDEF",
      ].join("\n"),
    );

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

    const report = readJsonReport(repoDir);
    const securityCheck = report.checks.find((c: { name: string }) =>
      c.name.includes("secret-pattern scan"),
    );
    expect(securityCheck).toBeTruthy();
    expect(securityCheck.passed).toBe(false);
  });
});
