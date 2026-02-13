import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { afterEach, describe, expect, it } from "vitest";

function writeFile(targetPath: string, content: string) {
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  fs.writeFileSync(targetPath, content, "utf8");
}

function runMigrateSpecs(repoDir: string, change: string) {
  const pwsh = process.platform === "win32" ? "powershell.exe" : "pwsh";
  return spawnSync(
    pwsh,
    [
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      "./scripts/openspec-migrate-specs.ps1",
      "-Change",
      change,
      "-Apply",
      "-NoValidate",
    ],
    {
      cwd: repoDir,
      encoding: "utf8",
    },
  );
}

function bootstrapRepo(repoDir: string) {
  const migrateScriptSource = path.join(process.cwd(), "scripts", "openspec-migrate-specs.ps1");
  writeFile(
    path.join(repoDir, "scripts", "openspec-migrate-specs.ps1"),
    fs.readFileSync(migrateScriptSource, "utf8"),
  );
}

describe("openspec migrate-specs", () => {
  const tempDirs: string[] = [];

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
    tempDirs.length = 0;
  });

  it("merges delta into canonical spec without overwriting existing requirements", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-migrate-specs-"));
    tempDirs.push(repoDir);
    bootstrapRepo(repoDir);

    writeFile(
      path.join(repoDir, "openspec", "specs", "sample-capability", "spec.md"),
      [
        "# sample-capability Specification",
        "",
        "## Purpose",
        "Preserve canonical requirements.",
        "",
        "## Requirements",
        "",
        "### Requirement: Existing Behavior",
        "The system SHALL keep baseline behavior.",
        "",
        "#### Scenario: Baseline flow",
        "- **WHEN** baseline condition applies",
        "- **THEN** baseline output remains stable",
        "",
        "### Requirement: Legacy Guardrail",
        "The system SHALL keep an existing guardrail.",
      ].join("\n"),
    );

    writeFile(
      path.join(
        repoDir,
        "openspec",
        "changes",
        "fix-migrate-specs-merge",
        "specs",
        "sample-capability",
        "spec.md",
      ),
      [
        "## ADDED Requirements",
        "",
        "### Requirement: New Capability",
        "The system SHALL expose a newly added behavior.",
        "",
        "#### Scenario: New behavior path",
        "- **WHEN** contributors run migrate-specs",
        "- **THEN** merge output includes newly added requirement content",
        "",
        "## MODIFIED Requirements",
        "",
        "### Requirement: Existing Behavior",
        "",
        "#### Scenario: Additional flow",
        "- **WHEN** delta introduces a new scenario",
        "- **THEN** canonical keeps old scenarios and appends the new one",
      ].join("\n"),
    );

    const firstApply = runMigrateSpecs(repoDir, "fix-migrate-specs-merge");
    expect(firstApply.status).toBe(0);

    const mergedPath = path.join(repoDir, "openspec", "specs", "sample-capability", "spec.md");
    const mergedOnce = fs.readFileSync(mergedPath, "utf8").replace(/\r\n/g, "\n");
    expect(mergedOnce).toContain("### Requirement: Legacy Guardrail");
    expect(mergedOnce).toContain("#### Scenario: Baseline flow");
    expect(mergedOnce).toContain("#### Scenario: Additional flow");
    expect(mergedOnce).toContain("### Requirement: New Capability");

    const secondApply = runMigrateSpecs(repoDir, "fix-migrate-specs-merge");
    expect(secondApply.status).toBe(0);
    const mergedTwice = fs.readFileSync(mergedPath, "utf8").replace(/\r\n/g, "\n");
    expect(mergedTwice).toBe(mergedOnce);
  });

  it("fails when delta modifies a requirement that does not exist in canonical spec", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-migrate-specs-fail-"));
    tempDirs.push(repoDir);
    bootstrapRepo(repoDir);

    writeFile(
      path.join(repoDir, "openspec", "specs", "sample-capability", "spec.md"),
      [
        "# sample-capability Specification",
        "",
        "## Purpose",
        "Sample purpose.",
        "",
        "## Requirements",
        "",
        "### Requirement: Existing Behavior",
        "The system SHALL keep baseline behavior.",
      ].join("\n"),
    );

    writeFile(
      path.join(
        repoDir,
        "openspec",
        "changes",
        "fix-migrate-specs-merge",
        "specs",
        "sample-capability",
        "spec.md",
      ),
      [
        "## MODIFIED Requirements",
        "",
        "### Requirement: Missing Behavior",
        "Updated body that should fail because canonical block is missing.",
      ].join("\n"),
    );

    const result = runMigrateSpecs(repoDir, "fix-migrate-specs-merge");
    expect(result.status).not.toBe(0);
    expect(result.stderr).toContain("cannot modify missing requirement");
  });
});
