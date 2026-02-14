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

function runFlow(repoDir: string, args: string[]) {
  const pwsh = process.platform === "win32" ? "powershell.exe" : "pwsh";
  return run(
    pwsh,
    ["-ExecutionPolicy", "Bypass", "-File", "./scripts/sbk.ps1", "flow", "run", ...args],
    repoDir,
  );
}

describe("sbk flow", () => {
  const tempDirs: string[] = [];

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
    tempDirs.length = 0;
  });

  it("runs end-to-end greenfield flow in auto mode", () => {
    const targetRepo = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-flow-greenfield-"));
    tempDirs.push(targetRepo);

    const result = runFlow(process.cwd(), [
      "--target-repo-root",
      targetRepo,
      "--decision-mode",
      "auto",
      "--scenario",
      "auto",
      "--project-name",
      "Flow Greenfield",
      "--project-type",
      "backend",
      "--with-install",
      "--preset",
      "minimal",
      "--skip-verify",
    ]);
    expect(result.status).toBe(0);

    expect(fs.existsSync(path.join(targetRepo, "PROJECT.md"))).toBe(true);
    expect(fs.existsSync(path.join(targetRepo, ".sbk", "blueprint.lock.json"))).toBe(true);
    expect(fs.existsSync(path.join(targetRepo, ".metrics", "intake-readiness.json"))).toBe(true);

    const flowReportPath = path.join(targetRepo, ".metrics", "flow-run-report.json");
    expect(fs.existsSync(flowReportPath)).toBe(true);
    const report = JSON.parse(fs.readFileSync(flowReportPath, "utf8").replace(/^\uFEFF/, ""));
    expect(report.status).toBe("passed");
    expect(report.decisions.scenario).toBe("greenfield");
    expect(report.decisions.blueprint).toBeTypeOf("string");
    expect(Array.isArray(report.stages)).toBe(true);
    expect(report.stages.length).toBeGreaterThan(3);
  }, 45000);

  it("runs brownfield flow with explicit python adapter", () => {
    const targetRepo = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-flow-brownfield-"));
    tempDirs.push(targetRepo);
    writeFile(path.join(targetRepo, "src", "main.py"), "def greet():\n    return 'hello'\n");
    writeFile(path.join(targetRepo, "tests", "test_main.py"), "from src.main import greet\n");

    const result = runFlow(process.cwd(), [
      "--target-repo-root",
      targetRepo,
      "--decision-mode",
      "auto",
      "--scenario",
      "auto",
      "--adapter",
      "python",
      "--project-type",
      "backend",
      "--with-install",
      "--preset",
      "minimal",
      "--skip-verify",
    ]);
    expect(result.status).toBe(0);

    const flowReportPath = path.join(targetRepo, ".metrics", "flow-run-report.json");
    const readinessPath = path.join(targetRepo, ".metrics", "intake-readiness.json");
    expect(fs.existsSync(flowReportPath)).toBe(true);
    expect(fs.existsSync(readinessPath)).toBe(true);

    const report = JSON.parse(fs.readFileSync(flowReportPath, "utf8").replace(/^\uFEFF/, ""));
    expect(report.status).toBe("passed");
    expect(report.decisions.scenario).toBe("brownfield");
    expect(report.decisions.adapter).toBe("python");
    const stageNames = report.stages.map((stage: { name: string }) => stage.name);
    expect(stageNames).toContain("intake analyze");
    expect(stageNames).toContain("adapter doctor");
  }, 45000);
});
