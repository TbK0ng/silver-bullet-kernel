Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Command
  )

  Write-Host "[verify] $Name"
  Invoke-Expression $Command
  if ($LASTEXITCODE -ne 0) {
    throw "[verify] step failed: $Name"
  }
}

Invoke-Step -Name "lint" -Command "npm run lint"
Invoke-Step -Name "typecheck" -Command "npm run typecheck"
Invoke-Step -Name "test" -Command "npm run test"
Invoke-Step -Name "build" -Command "npm run build"

Write-Host "[verify] completed"
