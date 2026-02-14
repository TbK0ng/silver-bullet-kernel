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

function runSbk(repoDir: string, args: string[]) {
  const pwsh = process.platform === "win32" ? "powershell.exe" : "pwsh";
  return run(pwsh, ["-ExecutionPolicy", "Bypass", "-File", "./scripts/sbk.ps1", ...args], repoDir);
}

function bootstrapFleetCollector(repoDir: string) {
  copyFromRepo("scripts/sbk.ps1", repoDir);
  copyFromRepo("scripts/sbk-fleet.ps1", repoDir);
  copyFromRepo("scripts/common/sbk-runtime.ps1", repoDir);
}

describe("sbk fleet + channel rollout", () => {
  const tempDirs: string[] = [];

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
    tempDirs.length = 0;
  });

  it("collects and reports fleet indicators across repos", () => {
    const collector = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-fleet-collector-"));
    const repoA = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-fleet-a-"));
    const repoB = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-fleet-b-"));
    tempDirs.push(collector, repoA, repoB);

    bootstrapFleetCollector(collector);

    const policy = {
      indicatorGate: {
        maxFailureRateLast7Days: 5,
        maxLeadTimeHoursP90: 72,
        maxReworkCountLast7Days: 2,
        maxSpecDriftEventsLast30Days: 1,
        requireTokenCostAvailable: false,
      },
    };
    writeFile(path.join(repoA, "workflow-policy.json"), JSON.stringify(policy, null, 2));
    writeFile(path.join(repoB, "workflow-policy.json"), JSON.stringify(policy, null, 2));

    writeFile(
      path.join(repoA, ".metrics", "workflow-metrics-latest.json"),
      JSON.stringify(
        {
          totals: {
            last7DaysFailureRate: 2,
          },
          indicators: {
            leadTimeHoursP90: 20,
            reworkCountLast7Days: 1,
            specDriftEventsLast30Days: 0,
            tokenCost: { status: "available" },
          },
        },
        null,
        2,
      ),
    );

    writeFile(
      path.join(repoB, ".metrics", "workflow-metrics-latest.json"),
      JSON.stringify(
        {
          totals: {
            last7DaysFailureRate: 12,
          },
          indicators: {
            leadTimeHoursP90: 90,
            reworkCountLast7Days: 6,
            specDriftEventsLast30Days: 4,
            tokenCost: { status: "unavailable" },
          },
        },
        null,
        2,
      ),
    );

    const collect = runSbk(collector, [
      "fleet",
      "collect",
      "--roots",
      `${repoA},${repoB}`,
    ]);
    expect(collect.status).toBe(0);
    expect(fs.existsSync(path.join(collector, ".metrics", "fleet-snapshot.json"))).toBe(true);

    const report = runSbk(collector, ["fleet", "report", "--format", "json"]);
    expect(report.status).toBe(0);
    const fleetReport = JSON.parse(
      fs
        .readFileSync(path.join(collector, ".metrics", "fleet-report.json"), "utf8")
        .replace(/^\uFEFF/, ""),
    );
    expect(fleetReport.repositories).toBe(2);
    expect(fleetReport.repositoriesExceedingThresholds.length).toBeGreaterThanOrEqual(1);
  });

  it("blocks unsafe channel transition and records safe rollout audit", () => {
    const targetUnsafe = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-channel-unsafe-"));
    tempDirs.push(targetUnsafe);
    writeFile(path.join(targetUnsafe, "package.json"), "{\"name\":\"unsafe\",\"scripts\":{}}\n");
    writeFile(
      path.join(targetUnsafe, ".sbk", "release-manifest.json"),
      JSON.stringify(
        {
          channel: "stable",
          version: "2.0.0",
          publishedAt: "2025-01-01T00:00:00Z",
          transition: {
            safe: true,
            toChannel: "stable",
            toVersion: "2.0.0",
          },
        },
        null,
        2,
      ),
    );

    const unsafe = runSbk(process.cwd(), [
      "install",
      "--target-repo-root",
      targetUnsafe,
      "--preset",
      "minimal",
      "--channel",
      "stable",
    ]);
    expect(unsafe.status).not.toBe(0);
    expect(unsafe.stdout + unsafe.stderr).toContain("unsafe channel transition");

    const targetSafe = fs.mkdtempSync(path.join(os.tmpdir(), "sbk-channel-safe-"));
    tempDirs.push(targetSafe);
    writeFile(path.join(targetSafe, "package.json"), "{\"name\":\"safe\",\"scripts\":{}}\n");

    const installBeta = runSbk(process.cwd(), [
      "install",
      "--target-repo-root",
      targetSafe,
      "--preset",
      "minimal",
      "--channel",
      "beta",
    ]);
    expect(installBeta.status).toBe(0);

    const upgradeStable = runSbk(process.cwd(), [
      "upgrade",
      "--target-repo-root",
      targetSafe,
      "--preset",
      "minimal",
      "--channel",
      "stable",
    ]);
    expect(upgradeStable.status).toBe(0);

    const releaseManifestPath = path.join(targetSafe, ".sbk", "release-manifest.json");
    expect(fs.existsSync(releaseManifestPath)).toBe(true);
    const releaseManifest = JSON.parse(
      fs.readFileSync(releaseManifestPath, "utf8").replace(/^\uFEFF/, ""),
    );
    expect(releaseManifest.channel).toBe("stable");
    expect(releaseManifest.transition.safe).toBe(true);

    const auditPath = path.join(targetSafe, ".metrics", "channel-rollout-audit.jsonl");
    expect(fs.existsSync(auditPath)).toBe(true);
    const lines = fs
      .readFileSync(auditPath, "utf8")
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line.length > 0);
    expect(lines.length).toBeGreaterThanOrEqual(2);
  });
});
