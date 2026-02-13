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

function copyFileFromRepo(repoRelativePath: string, targetRepoDir: string) {
  const sourcePath = path.join(process.cwd(), repoRelativePath);
  const targetPath = path.join(targetRepoDir, repoRelativePath);
  writeFile(targetPath, fs.readFileSync(sourcePath, "utf8"));
}

function bootstrapGreenfieldRepo(repoDir: string) {
  copyFileFromRepo("scripts/sbk.ps1", repoDir);
  copyFileFromRepo("scripts/greenfield-bootstrap.ps1", repoDir);
  copyFileFromRepo("scripts/common/sbk-runtime.ps1", repoDir);

  const adapterDir = path.join(process.cwd(), "config", "adapters");
  for (const entry of fs.readdirSync(adapterDir)) {
    if (!entry.endsWith(".json")) {
      continue;
    }
    const relativePath = path.join("config", "adapters", entry);
    copyFileFromRepo(relativePath, repoDir);
  }
}

function runGreenfield(repoDir: string, args: string[]) {
  const pwsh = process.platform === "win32" ? "powershell.exe" : "pwsh";
  return run(
    pwsh,
    ["-ExecutionPolicy", "Bypass", "-File", "./scripts/sbk.ps1", "greenfield", ...args],
    repoDir,
  );
}

describe("sbk greenfield bootstrap", () => {
  const tempDirs: string[] = [];

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
    tempDirs.length = 0;
  });

  it("creates project artifacts, language stubs, and sbk config adapter", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-greenfield-create-"));
    tempDirs.push(repoDir);
    bootstrapGreenfieldRepo(repoDir);

    const result = runGreenfield(repoDir, [
      "--adapter",
      "node-ts",
      "--project-name",
      "Greenfield Demo",
      "--project-type",
      "fullstack",
    ]);
    expect(result.status).toBe(0);

    expect(fs.existsSync(path.join(repoDir, "PROJECT.md"))).toBe(true);
    expect(fs.existsSync(path.join(repoDir, "REQUIREMENTS.md"))).toBe(true);
    expect(fs.existsSync(path.join(repoDir, "ROADMAP.md"))).toBe(true);
    expect(fs.existsSync(path.join(repoDir, "STATE.md"))).toBe(true);
    expect(fs.existsSync(path.join(repoDir, "CONTEXT.md"))).toBe(true);
    expect(fs.existsSync(path.join(repoDir, ".planning", "research", ".gitkeep"))).toBe(true);

    expect(fs.existsSync(path.join(repoDir, "package.json"))).toBe(true);
    expect(fs.existsSync(path.join(repoDir, "src", "index.ts"))).toBe(true);
    expect(fs.existsSync(path.join(repoDir, "tests", "smoke.test.ts"))).toBe(true);

    const packageJson = JSON.parse(
      fs.readFileSync(path.join(repoDir, "package.json"), "utf8").replace(/^\uFEFF/, ""),
    );
    expect(packageJson.name).toBe("greenfield-demo");

    const sbkConfig = JSON.parse(
      fs.readFileSync(path.join(repoDir, "sbk.config.json"), "utf8").replace(/^\uFEFF/, ""),
    );
    expect(sbkConfig.adapter).toBe("node-ts");
  });

  it("keeps existing files when rerun without force", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-greenfield-idempotent-"));
    tempDirs.push(repoDir);
    bootstrapGreenfieldRepo(repoDir);

    const firstRun = runGreenfield(repoDir, ["--adapter", "python", "--project-name", "Demo"]);
    expect(firstRun.status).toBe(0);

    writeFile(path.join(repoDir, "PROJECT.md"), "# PROJECT\n\ncustom-content\n");

    const secondRun = runGreenfield(repoDir, [
      "--adapter",
      "python",
      "--project-name",
      "Changed Name",
    ]);
    expect(secondRun.status).toBe(0);

    const projectContent = fs.readFileSync(path.join(repoDir, "PROJECT.md"), "utf8");
    expect(projectContent).toContain("custom-content");
  });

  it("overwrites existing files when force is enabled", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-greenfield-force-"));
    tempDirs.push(repoDir);
    bootstrapGreenfieldRepo(repoDir);

    const firstRun = runGreenfield(repoDir, ["--adapter", "go", "--project-name", "Original"]);
    expect(firstRun.status).toBe(0);

    writeFile(path.join(repoDir, "PROJECT.md"), "# PROJECT\n\ncustom-content\n");

    const forceRun = runGreenfield(repoDir, [
      "--adapter",
      "go",
      "--project-name",
      "Forced Name",
      "--force",
    ]);
    expect(forceRun.status).toBe(0);

    const projectContent = fs.readFileSync(path.join(repoDir, "PROJECT.md"), "utf8");
    expect(projectContent).toContain("Forced Name");
    expect(projectContent).not.toContain("custom-content");
  });

  it("can skip language stubs while still creating planning artifacts", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-greenfield-no-stubs-"));
    tempDirs.push(repoDir);
    bootstrapGreenfieldRepo(repoDir);

    const result = runGreenfield(repoDir, [
      "--adapter",
      "rust",
      "--project-name",
      "No Stubs",
      "--no-language-stubs",
    ]);
    expect(result.status).toBe(0);

    expect(fs.existsSync(path.join(repoDir, "PROJECT.md"))).toBe(true);
    expect(fs.existsSync(path.join(repoDir, "REQUIREMENTS.md"))).toBe(true);
    expect(fs.existsSync(path.join(repoDir, "Cargo.toml"))).toBe(false);
    expect(fs.existsSync(path.join(repoDir, "src", "main.rs"))).toBe(false);

    const sbkConfig = JSON.parse(
      fs.readFileSync(path.join(repoDir, "sbk.config.json"), "utf8").replace(/^\uFEFF/, ""),
    );
    expect(sbkConfig.adapter).toBe("rust");
  });
});
