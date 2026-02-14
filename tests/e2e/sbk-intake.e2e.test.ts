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

function initGitRepo(repoDir: string) {
  run("git", ["init"], repoDir);
  run("git", ["config", "user.email", "test@example.com"], repoDir);
  run("git", ["config", "user.name", "sbk-test"], repoDir);
  run("git", ["add", "."], repoDir);
  run("git", ["commit", "-m", "init"], repoDir);
}

function runSbk(repoDir: string, args: string[]) {
  const pwsh = process.platform === "win32" ? "powershell.exe" : "pwsh";
  return run(pwsh, ["-ExecutionPolicy", "Bypass", "-File", "./scripts/sbk.ps1", ...args], repoDir);
}

function bootstrapIntakeRepo(repoDir: string) {
  copyFromRepo("scripts/sbk.ps1", repoDir);
  copyFromRepo("scripts/sbk-intake.ps1", repoDir);
  copyFromRepo("scripts/common/sbk-runtime.ps1", repoDir);
  copyFromRepo("workflow-policy.json", repoDir);

  const runtimeConfig = {
    version: 1,
    adapter: "python",
    profile: "strict",
    targetRepoRoot: ".",
    adaptersDir: "config/adapters",
    intake: {
      thresholds: {
        lite: { maxOverallRisk: 100, maxDimensionRisk: 100 },
        balanced: { maxOverallRisk: 100, maxDimensionRisk: 100 },
        strict: {
          maxOverallRisk: 100,
          maxDimensionRisk: 100,
          requiredArtifacts: [
            "workflow-policy.json",
            "sbk.config.json",
            "openspec/specs",
            "docs",
          ],
        },
      },
    },
  };
  writeFile(path.join(repoDir, "sbk.config.json"), JSON.stringify(runtimeConfig, null, 2));

  writeFile(path.join(repoDir, "src", "main.py"), "def add(a, b):\n    return a + b\n\nx = add(1, 2)\n");
  writeFile(path.join(repoDir, "tests", "test_main.py"), "from src.main import add\n\ndef test_add():\n    assert add(1, 2) == 3\n");
  writeFile(path.join(repoDir, "docs", "README.md"), "# docs\n");
  writeFile(path.join(repoDir, "openspec", "specs", "sample", "spec.md"), "## ADDED Requirements\n");
}

describe("sbk intake", () => {
  const tempDirs: string[] = [];

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
    tempDirs.length = 0;
  });

  it("runs analyze, plan, and verify with deterministic artifacts", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-intake-"));
    tempDirs.push(repoDir);
    bootstrapIntakeRepo(repoDir);
    initGitRepo(repoDir);

    const analyze = runSbk(repoDir, ["intake", "analyze", "--target-repo-root", repoDir]);
    expect(analyze.status).toBe(0);
    const riskProfilePath = path.join(repoDir, ".metrics", "intake-risk-profile.json");
    expect(fs.existsSync(riskProfilePath)).toBe(true);
    const riskProfile = JSON.parse(
      fs.readFileSync(riskProfilePath, "utf8").replace(/^\uFEFF/, ""),
    );
    expect(riskProfile.riskModel.overallRiskScore).toBeTypeOf("number");

    const plan = runSbk(repoDir, ["intake", "plan", "--target-repo-root", repoDir]);
    expect(plan.status).toBe(0);
    const planPath = path.join(repoDir, ".metrics", "intake-hardening-plan.json");
    expect(fs.existsSync(planPath)).toBe(true);
    const hardeningPlan = JSON.parse(fs.readFileSync(planPath, "utf8").replace(/^\uFEFF/, ""));
    expect(Array.isArray(hardeningPlan.phases)).toBe(true);
    expect(hardeningPlan.phases.map((p: { profile: string }) => p.profile)).toEqual([
      "lite",
      "balanced",
      "strict",
    ]);

    const verify = runSbk(repoDir, [
      "intake",
      "verify",
      "--target-repo-root",
      repoDir,
      "--profile",
      "strict",
    ]);
    expect(verify.status).toBe(0);
    const readinessPath = path.join(repoDir, ".metrics", "intake-readiness.json");
    expect(fs.existsSync(readinessPath)).toBe(true);
    const readiness = JSON.parse(fs.readFileSync(readinessPath, "utf8").replace(/^\uFEFF/, ""));
    expect(readiness.passed).toBe(true);
    expect(readiness.profile).toBe("strict");
  }, 15000);
});
