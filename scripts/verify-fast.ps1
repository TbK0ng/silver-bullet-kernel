Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Command
  )

  Write-Host "[verify-fast] $Name"
  Invoke-Expression $Command
  if ($LASTEXITCODE -ne 0) {
    throw "[verify-fast] step failed: $Name"
  }
}

Invoke-Step -Name "lint" -Command "npm run lint"
Invoke-Step -Name "typecheck" -Command "npm run typecheck"

Write-Host "[verify-fast] completed"
