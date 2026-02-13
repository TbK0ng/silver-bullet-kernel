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

function runSbk(repoDir: string, args: string[]) {
  const pwsh = process.platform === "win32" ? "powershell.exe" : "pwsh";
  return run(pwsh, ["-ExecutionPolicy", "Bypass", "-File", "./scripts/sbk.ps1", ...args], repoDir);
}

describe("sbk install and upgrade", () => {
  const tempDirs: string[] = [];

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
    tempDirs.length = 0;
  });

  it("installs minimal preset and injects missing package scripts", () => {
    const targetRepo = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-install-minimal-"));
    tempDirs.push(targetRepo);

    writeFile(
      path.join(targetRepo, "package.json"),
      JSON.stringify(
        {
          name: "target-repo",
          private: true,
          scripts: {
            test: "echo test",
          },
        },
        null,
        2,
      ),
    );

    const install = runSbk(process.cwd(), [
      "install",
      "--target-repo-root",
      targetRepo,
      "--preset",
      "minimal",
    ]);
    expect(install.status).toBe(0);

    expect(fs.existsSync(path.join(targetRepo, "scripts", "verify-fast.ps1"))).toBe(true);
    expect(fs.existsSync(path.join(targetRepo, "scripts", "sbk.ps1"))).toBe(true);
    expect(fs.existsSync(path.join(targetRepo, "workflow-policy.json"))).toBe(true);
    expect(
      fs.existsSync(
        path.join(
          targetRepo,
          "openspec",
          "specs",
          "codex-workflow-kernel",
          "spec.md",
        ),
      ),
    ).toBe(true);

    const packageJson = JSON.parse(
      fs.readFileSync(path.join(targetRepo, "package.json"), "utf8").replace(/^\uFEFF/, ""),
    );
    expect(packageJson.scripts.test).toBe("echo test");
    expect(packageJson.scripts["sbk"]).toBe(
      "powershell -ExecutionPolicy Bypass -File ./scripts/sbk.ps1",
    );
    expect(packageJson.scripts["verify:fast"]).toBe(
      "powershell -ExecutionPolicy Bypass -File ./scripts/verify-fast.ps1",
    );
  });

  it("keeps local changes on install rerun without overwrite", () => {
    const targetRepo = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-install-idempotent-"));
    tempDirs.push(targetRepo);
    writeFile(path.join(targetRepo, "package.json"), "{\"name\":\"x\",\"scripts\":{}}\n");

    const firstInstall = runSbk(process.cwd(), [
      "install",
      "--target-repo-root",
      targetRepo,
      "--preset",
      "minimal",
    ]);
    expect(firstInstall.status).toBe(0);

    const verifyFastPath = path.join(targetRepo, "scripts", "verify-fast.ps1");
    writeFile(verifyFastPath, "custom-content\n");

    const secondInstall = runSbk(process.cwd(), [
      "install",
      "--target-repo-root",
      targetRepo,
      "--preset",
      "minimal",
    ]);
    expect(secondInstall.status).toBe(0);
    expect(fs.readFileSync(verifyFastPath, "utf8")).toContain("custom-content");
  });

  it("overwrites existing files in upgrade mode", () => {
    const targetRepo = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-upgrade-overwrite-"));
    tempDirs.push(targetRepo);
    writeFile(path.join(targetRepo, "package.json"), "{\"name\":\"x\",\"scripts\":{}}\n");

    const firstInstall = runSbk(process.cwd(), [
      "install",
      "--target-repo-root",
      targetRepo,
      "--preset",
      "minimal",
    ]);
    expect(firstInstall.status).toBe(0);

    const verifyFastPath = path.join(targetRepo, "scripts", "verify-fast.ps1");
    writeFile(verifyFastPath, "custom-content\n");

    const upgrade = runSbk(process.cwd(), [
      "upgrade",
      "--target-repo-root",
      targetRepo,
      "--preset",
      "minimal",
    ]);
    expect(upgrade.status).toBe(0);
    expect(fs.readFileSync(verifyFastPath, "utf8")).not.toContain("custom-content");
  });

  it("installs full preset with adapter configs and docs", () => {
    const targetRepo = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-install-full-"));
    tempDirs.push(targetRepo);
    writeFile(path.join(targetRepo, "package.json"), "{\"name\":\"x\",\"scripts\":{}}\n");

    const install = runSbk(process.cwd(), [
      "install",
      "--target-repo-root",
      targetRepo,
      "--preset",
      "full",
    ]);
    expect(install.status).toBe(0);

    expect(
      fs.existsSync(path.join(targetRepo, "config", "adapters", "node-ts.json")),
    ).toBe(true);
    expect(fs.existsSync(path.join(targetRepo, "docs", "06-多项目类型接入与配置指南.md"))).toBe(
      true,
    );
    expect(fs.existsSync(path.join(targetRepo, "scripts", "sbk-install.ps1"))).toBe(true);
  });
});
