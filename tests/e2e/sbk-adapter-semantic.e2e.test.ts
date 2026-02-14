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

function runSbk(repoDir: string, args: string[]) {
  const pwsh = process.platform === "win32" ? "powershell.exe" : "pwsh";
  return run(pwsh, ["-ExecutionPolicy", "Bypass", "-File", "./scripts/sbk.ps1", ...args], repoDir);
}

function bootstrapAdapterRepo(repoDir: string) {
  copyFromRepo("scripts/sbk.ps1", repoDir);
  copyFromRepo("scripts/sbk-adapter.ps1", repoDir);
  copyFromRepo("scripts/sbk-semantic.ps1", repoDir);
  copyFromRepo("scripts/semantic-python.py", repoDir);
  copyFromRepo("scripts/semantic-index.py", repoDir);
  copyFromRepo("scripts/semantic-rename.ts", repoDir);
  copyFromRepo("scripts/common/sbk-runtime.ps1", repoDir);
  copyFromRepo("sbk.config.json", repoDir);
  copyDirectoryFromRepo("config/adapters", repoDir);
}

describe("sbk adapter + semantic", () => {
  const tempDirs: string[] = [];

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
    tempDirs.length = 0;
  });

  it("validates/registers plugin adapters and lists registry", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-adapter-"));
    tempDirs.push(repoDir);
    bootstrapAdapterRepo(repoDir);

    const packDir = path.join(repoDir, "tmp", "demo-pack");
    writeFile(
      path.join(packDir, "adapter.json"),
      JSON.stringify(
        {
          metadata: {
            name: "demo-python-plus",
            version: "1.0.0",
            author: "test",
            priority: 42,
          },
          detect: { anyOfFiles: ["pyproject.toml"] },
          implementation: {
            pathPrefixes: ["src/", "tests/"],
            pathFiles: ["pyproject.toml"],
          },
          verify: {
            fast: ["python -m pytest -q"],
            full: ["python -m pytest"],
            ci: ["python -m pytest --maxfail=1"],
          },
          capabilities: {
            semantic: {
              rename: { supported: true, backend: "python-ast", deterministic: true },
              referenceMap: { supported: false, backend: "python-ast", deterministic: false },
              safeDeleteCandidates: {
                supported: false,
                backend: "python-ast",
                deterministic: false,
              },
            },
          },
        },
        null,
        2,
      ),
    );

    const validate = runSbk(repoDir, ["adapter", "validate", "--path", packDir]);
    expect(validate.status).toBe(0);

    const register = runSbk(repoDir, ["adapter", "register", "--path", packDir]);
    expect(register.status).toBe(0);
    expect(
      fs.existsSync(path.join(repoDir, "config", "adapters", "plugins", "demo-python-plus.json")),
    ).toBe(true);

    const list = runSbk(repoDir, ["adapter", "list"]);
    expect(list.status).toBe(0);
    expect(list.stdout).toContain("demo-python-plus");
    expect(list.stdout).toContain("source=plugin");
  });

  it("routes semantic operations for python and deterministic index adapters", () => {
    const repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-semantic-"));
    tempDirs.push(repoDir);
    bootstrapAdapterRepo(repoDir);

    const runtimeConfig = {
      version: 1,
      adapter: "python",
      profile: "strict",
      targetRepoRoot: ".",
      adaptersDir: "config/adapters",
    };
    writeFile(path.join(repoDir, "sbk.config.json"), JSON.stringify(runtimeConfig, null, 2));
    writeFile(
      path.join(repoDir, "src", "module.py"),
      [
        "def greet(name):",
        "    return f'hello {name}'",
        "",
        "value = greet('world')",
      ].join("\n"),
    );

    const renamePython = runSbk(repoDir, [
      "semantic",
      "rename",
      "--file",
      "src/module.py",
      "--line",
      "1",
      "--column",
      "5",
      "--new-name",
      "greet_user",
      "--target-repo-root",
      repoDir,
    ]);
    expect(renamePython.status).toBe(0);
    const pythonContent = fs.readFileSync(path.join(repoDir, "src", "module.py"), "utf8");
    expect(pythonContent).toContain("def greet_user(name):");
    expect(pythonContent).toContain("value = greet_user('world')");

    const semanticReportPath = path.join(repoDir, ".metrics", "semantic-operation-report.json");
    expect(fs.existsSync(semanticReportPath)).toBe(true);
    const report = JSON.parse(
      fs.readFileSync(semanticReportPath, "utf8").replace(/^\uFEFF/, ""),
    );
    expect(report.status).toBe("passed");
    expect(report.adapter).toBe("python");

    const referenceMap = runSbk(repoDir, [
      "semantic",
      "reference-map",
      "--file",
      "src/module.py",
      "--line",
      "1",
      "--column",
      "7",
      "--target-repo-root",
      repoDir,
    ]);
    expect(referenceMap.status).toBe(0);
    const refReport = JSON.parse(
      fs.readFileSync(semanticReportPath, "utf8").replace(/^\uFEFF/, ""),
    );
    expect(refReport.status).toBe("passed");
    expect(refReport.result.operation).toBe("reference-map");
    expect(refReport.result.summary.totalReferences).toBeGreaterThanOrEqual(2);

    const safeDelete = runSbk(repoDir, [
      "semantic",
      "safe-delete-candidates",
      "--file",
      "src/module.py",
      "--line",
      "1",
      "--column",
      "7",
      "--target-repo-root",
      repoDir,
    ]);
    expect(safeDelete.status).toBe(0);
    const safeDeleteReport = JSON.parse(
      fs.readFileSync(semanticReportPath, "utf8").replace(/^\uFEFF/, ""),
    );
    expect(safeDeleteReport.status).toBe("passed");
    expect(safeDeleteReport.result.operation).toBe("safe-delete-candidates");

    const scenarios = [
      {
        adapter: "rust",
        file: "src/main.rs",
        content: "fn greet() {}\nfn main() { greet(); }\n",
        line: "1",
        column: "5",
      },
      {
        adapter: "go",
        file: "cmd/app/main.go",
        content: "package main\n\nfunc greet() {}\n\nfunc main() { greet() }\n",
        line: "3",
        column: "7",
      },
      {
        adapter: "java",
        file: "src/main/java/App.java",
        content:
          "public class App {\n  static void greet() {}\n  public static void main(String[] args) { greet(); }\n}\n",
        line: "2",
        column: "16",
      },
    ];

    for (const scenario of scenarios) {
      runtimeConfig.adapter = scenario.adapter;
      writeFile(path.join(repoDir, "sbk.config.json"), JSON.stringify(runtimeConfig, null, 2));
      writeFile(path.join(repoDir, scenario.file), scenario.content);

      const rename = runSbk(repoDir, [
        "semantic",
        "rename",
        "--file",
        scenario.file,
        "--line",
        scenario.line,
        "--column",
        scenario.column,
        "--new-name",
        "greet_user",
        "--target-repo-root",
        repoDir,
      ]);
      expect(rename.status).toBe(0);

      const changedContent = fs.readFileSync(path.join(repoDir, scenario.file), "utf8");
      expect(changedContent).toContain("greet_user");
    }
  }, 30000);
});
