Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Command
  )

  Write-Host "[verify-ci] $Name"
  Invoke-Expression $Command
  if ($LASTEXITCODE -ne 0) {
    throw "[verify-ci] step failed: $Name"
  }
}

Invoke-Step -Name "lint" -Command "npm run lint"
Invoke-Step -Name "typecheck" -Command "npm run typecheck"
Invoke-Step -Name "unit and integration tests" -Command "npm run test"
Invoke-Step -Name "e2e tests" -Command "npm run test:e2e"
Invoke-Step -Name "build" -Command "npm run build"
Invoke-Step -Name "OpenSpec strict validation" -Command "openspec validate --all --strict --no-interactive"

Write-Host "[verify-ci] completed"
