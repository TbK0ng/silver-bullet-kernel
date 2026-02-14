import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { afterEach, describe, expect, it } from "vitest";

function run(command: string, args: string[], cwd: string) {
  return spawnSync(command, args, {
    cwd,
    encoding: "utf8",
    env: {
      ...process.env,
    },
  });
}

function writeFile(targetPath: string, content: string) {
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  fs.writeFileSync(targetPath, content, "utf8");
}

function copyFromRepo(repoRelativePath: string, targetRepoDir: string) {
  const source = path.join(process.cwd(), repoRelativePath);
  const target = path.join(targetRepoDir, repoRelativePath);
  writeFile(target, fs.readFileSync(source, "utf8"));
}

function copyDirectoryFromRepo(repoRelativeDir: string, targetRepoDir: string) {
  const sourceDir = path.join(process.cwd(), repoRelativeDir);
  const entries = fs.readdirSync(sourceDir, { withFileTypes: true });
  for (const entry of entries) {
    const rel = path.join(repoRelativeDir, entry.name);
    if (entry.isDirectory()) {
      copyDirectoryFromRepo(rel, targetRepoDir);
      continue;
    }
    copyFromRepo(rel, targetRepoDir);
  }
}

function bootstrapBlueprintRepo(repoDir: string) {
  copyFromRepo("scripts/sbk.ps1", repoDir);
  copyFromRepo("scripts/sbk-blueprint.ps1", repoDir);
  copyFromRepo("scripts/common/sbk-runtime.ps1", repoDir);
  copyDirectoryFromRepo("config/blueprints", repoDir);
}

function runSbk(repoDir: string, args: string[]) {
  const pwsh = process.platform === "win32" ? "powershell.exe" : "pwsh";
  return run(pwsh, ["-ExecutionPolicy", "Bypass", "-File", "./scripts/sbk.ps1", ...args], repoDir);
}

describe("sbk blueprint", () => {
  const tempDirs: string[] = [];

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
    tempDirs.length = 0;
  });

  it("lists, applies, and verifies blueprint baseline", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-blueprint-"));
    tempDirs.push(repoDir);
    bootstrapBlueprintRepo(repoDir);

    const list = runSbk(repoDir, ["blueprint", "list"]);
    expect(list.status).toBe(0);
    expect(list.stdout).toContain("api-service");
    expect(list.stdout).toContain("channel=stable");

    const apply = runSbk(repoDir, [
      "blueprint",
      "apply",
      "--name",
      "api-service",
      "--target-repo-root",
      repoDir,
      "--adapter",
      "node-ts",
    ]);
    expect(apply.status).toBe(0);
    expect(fs.existsSync(path.join(repoDir, ".github", "workflows", "ci.yml"))).toBe(true);
    expect(fs.existsSync(path.join(repoDir, "docs", "runbooks", "operations.md"))).toBe(true);
    expect(
      fs.existsSync(path.join(repoDir, "docs", "architecture", "openapi-contract.md")),
    ).toBe(true);
    expect(fs.existsSync(path.join(repoDir, ".sbk", "blueprint.lock.json"))).toBe(true);

    const verifyPass = runSbk(repoDir, ["blueprint", "verify", "--target-repo-root", repoDir]);
    expect(verifyPass.status).toBe(0);
    expect(fs.existsSync(path.join(repoDir, ".metrics", "blueprint-verify.json"))).toBe(true);

    fs.rmSync(path.join(repoDir, "docs", "runbooks", "operations.md"), { force: true });
    const verifyFail = runSbk(repoDir, ["blueprint", "verify", "--target-repo-root", repoDir]);
    expect(verifyFail.status).not.toBe(0);
    expect(verifyFail.stdout + verifyFail.stderr).toContain("missing");
  }, 15000);
});
