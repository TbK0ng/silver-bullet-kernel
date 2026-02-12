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

describe("semantic rename command", () => {
  const tempDirs: string[] = [];

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
    tempDirs.length = 0;
  });

  it("supports dry-run and apply rename", () => {
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-semantic-rename-"));
    tempDirs.push(tempDir);

    fs.mkdirSync(path.join(tempDir, "src"), { recursive: true });
    fs.writeFileSync(
      path.join(tempDir, "tsconfig.json"),
      JSON.stringify(
        {
          compilerOptions: {
            target: "ES2020",
            module: "ESNext",
            moduleResolution: "Node",
            strict: true,
          },
          include: ["src/**/*.ts"],
        },
        null,
        2,
      ),
      "utf8",
    );
    fs.writeFileSync(
      path.join(tempDir, "src", "math.ts"),
      [
        "export function add(a: number, b: number): number {",
        "  return a + b;",
        "}",
        "",
        "export const first = add(1, 2);",
      ].join("\n"),
      "utf8",
    );

    const scriptPath = path.join(process.cwd(), "scripts", "semantic-rename.ts");
    const npmExecPath = process.env.npm_execpath;
    expect(npmExecPath).toBeTruthy();
    const npmCommand = process.execPath;

    const dryRun = run(
      npmCommand,
      [
        npmExecPath as string,
        "exec",
        "--",
        "tsx",
        scriptPath,
        "--file",
        "src/math.ts",
        "--line",
        "1",
        "--column",
        "17",
        "--newName",
        "sum",
        "--dryRun",
      ],
      tempDir,
    );
    expect(dryRun.status).toBe(0);
    const dryPayload = JSON.parse(dryRun.stdout);
    expect(dryPayload.mode).toBe("dry-run");
    expect(dryPayload.touchedFiles).toBeGreaterThanOrEqual(1);
    expect(dryPayload.touchedLocations).toBeGreaterThanOrEqual(2);
    const afterDryRun = fs.readFileSync(path.join(tempDir, "src", "math.ts"), "utf8");
    expect(afterDryRun).toContain("function add");
    expect(afterDryRun).not.toContain("function sum");

    const applyRun = run(
      npmCommand,
      [
        npmExecPath as string,
        "exec",
        "--",
        "tsx",
        scriptPath,
        "--file",
        "src/math.ts",
        "--line",
        "1",
        "--column",
        "17",
        "--newName",
        "sum",
      ],
      tempDir,
    );
    expect(applyRun.status).toBe(0);
    const applyPayload = JSON.parse(applyRun.stdout);
    expect(applyPayload.mode).toBe("apply");
    expect(applyPayload.to).toBe("sum");

    const afterApply = fs.readFileSync(path.join(tempDir, "src", "math.ts"), "utf8");
    expect(afterApply).toContain("function sum");
    expect(afterApply).toContain("first = sum(1, 2)");
  }, 30000);
});
