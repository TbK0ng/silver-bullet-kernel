Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$outputDir = Join-Path $PSScriptRoot "..\\xxx_docs\\generated"
$outputPath = Join-Path $outputDir "codebase-map.md"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if (-not (Test-Path $outputDir)) {
  New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$topLevel = Get-ChildItem -Path $repoRoot -Force |
  Where-Object { $_.Name -notin @(".git", "node_modules", "dist") } |
  Sort-Object Name |
  ForEach-Object {
    if ($_.PSIsContainer) {
      "- dir: $($_.Name)"
    } else {
      "- file: $($_.Name)"
    }
  }

$trackedFiles = @(git -C $repoRoot ls-files)
$untrackedFiles = @(git -C $repoRoot ls-files --others --exclude-standard)
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$content = @(
  "# Codebase Map",
  "",
  "- generated_at: $timestamp",
  "- repo_root: $repoRoot",
  "",
  "## Top-Level",
  ""
) + $topLevel + @(
  "",
  "## Tracked Files",
  ""
)

if ($trackedFiles.Count -eq 0) {
  $content += "- (none)"
} else {
  $content += ($trackedFiles | ForEach-Object { "- $_" })
}

$content += @(
  "",
  "## Untracked Files",
  ""
)

if ($untrackedFiles.Count -eq 0) {
  $content += "- (none)"
} else {
  $content += ($untrackedFiles | ForEach-Object { "- $_" })
}

Set-Content -Path $outputPath -Encoding UTF8 -Value $content
Write-Host "Wrote codebase map to $outputPath"
