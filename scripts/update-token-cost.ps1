param(
  [Parameter(Mandatory = $true)][string]$Source,
  [Parameter(Mandatory = $true)][double]$TotalCostUsd,
  [double]$TotalInputTokens = 0,
  [double]$TotalOutputTokens = 0,
  [string]$Notes = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$metricsDir = Join-Path $repoRoot ".metrics"
$tokenCostPath = Join-Path $metricsDir "token-cost.json"

if (-not (Test-Path $metricsDir)) {
  New-Item -ItemType Directory -Path $metricsDir | Out-Null
}

$summary = [ordered]@{
  source = $Source
  updatedAt = [DateTimeOffset]::UtcNow.ToString("o")
  totalCostUsd = [math]::Round($TotalCostUsd, 6)
  totalInputTokens = [math]::Round($TotalInputTokens, 0)
  totalOutputTokens = [math]::Round($TotalOutputTokens, 0)
  notes = $Notes
}

Set-Content -Path $tokenCostPath -Encoding UTF8 -Value ($summary | ConvertTo-Json -Depth 6)
Write-Host "Wrote token-cost summary: $tokenCostPath"
