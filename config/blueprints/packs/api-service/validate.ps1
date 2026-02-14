param(
  [Parameter(Mandatory = $true)][string]$TargetRepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$required = @(
  "docs/architecture/openapi-contract.md",
  "docs/runbooks/operations.md",
  ".sbk/verify-map.json"
)

$missing = @()
foreach ($relative in $required) {
  $path = Join-Path $TargetRepoRoot ($relative -replace "/", "\")
  if (-not (Test-Path $path)) {
    $missing += $relative
  }
}

if ($missing.Count -gt 0) {
  throw "[blueprint-validate] api-service missing artifacts: $($missing -join ', ')"
}
