param(
  [string]$Change = "",
  [switch]$IncludeApplyContext
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Invoke-OpenSpec {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Args
  )

  Push-Location $repoRoot
  try {
    & openspec @Args
    if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
      throw "openspec command failed: openspec $($Args -join ' ')"
    }
  } finally {
    Pop-Location
  }
}

if ([string]::IsNullOrWhiteSpace($Change)) {
  Write-Host "## OpenSpec Explore Context"
  Invoke-OpenSpec -Args @("list", "--json")
  Write-Host ""
  Write-Host "Tip: use `sbk explore --change <change-id> --include-apply-context` for deeper context."
  exit 0
}

Write-Host "## OpenSpec Explore Context: $Change"
Invoke-OpenSpec -Args @("status", "--change", $Change, "--json")

if ($IncludeApplyContext) {
  Write-Host ""
  Invoke-OpenSpec -Args @("instructions", "apply", "--change", $Change, "--json")
}

