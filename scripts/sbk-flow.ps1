param(
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$CommandArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "common\\sbk-runtime.ps1")

function Show-Usage {
  Write-Host "sbk flow run [options]"
  Write-Host ""
  Write-Host "Options:"
  Write-Host "  --target-repo-root <path>"
  Write-Host "  --decision-mode auto|ask"
  Write-Host "  --scenario auto|greenfield|brownfield"
  Write-Host "  --adapter <node-ts|python|go|java|rust>"
  Write-Host "  --profile <strict|balanced|lite>"
  Write-Host "  --project-name <name>"
  Write-Host "  --project-type <backend|frontend|fullstack>"
  Write-Host "  --blueprint <name|none>"
  Write-Host "  --allow-beta"
  Write-Host "  --channel <stable|beta>"
  Write-Host "  --preset <minimal|full>"
  Write-Host "  --with-install"
  Write-Host "  --skip-verify"
  Write-Host "  --fleet-roots <path1,path2,...>"
  Write-Host "  --force"
  Write-Host ""
  Write-Host "Examples:"
  Write-Host "  sbk flow run --decision-mode auto --scenario auto --target-repo-root ."
  Write-Host "  sbk flow run --decision-mode ask --scenario greenfield --project-type backend"
}

function Resolve-TargetRepoRoot {
  param(
    [Parameter(Mandatory = $true)][string]$Path
  )

  $resolved = Resolve-SbkPath -BasePath $repoRoot -Path $Path
  if (-not (Test-Path $resolved)) {
    New-Item -ItemType Directory -Path $resolved -Force | Out-Null
  }
  return (Resolve-Path -LiteralPath $resolved).Path
}

function Get-ShellCommand {
  if (Get-Command powershell -ErrorAction SilentlyContinue) {
    return "powershell"
  }
  return "pwsh"
}

function Prompt-Choice {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Choices,
    [Parameter(Mandatory = $true)][string]$DefaultValue
  )

  $choiceText = if ($Choices.Count -gt 0) { $Choices -join "/" } else { "value" }
  $inputValue = Read-Host ("[flow] choose {0} ({1}) [default: {2}]" -f $Name, $choiceText, $DefaultValue)
  if ([string]::IsNullOrWhiteSpace($inputValue)) {
    return $DefaultValue
  }
  if ($Choices.Count -gt 0 -and -not ($Choices -contains $inputValue)) {
    Write-Host ("[flow] invalid {0}='{1}', fallback to default '{2}'" -f $Name, $inputValue, $DefaultValue)
    return $DefaultValue
  }
  return $inputValue
}

function Prompt-Boolean {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][bool]$DefaultValue
  )

  $defaultText = if ($DefaultValue) { "y" } else { "n" }
  $inputValue = Read-Host ("[flow] {0}? [y/n, default: {1}]" -f $Name, $defaultText)
  if ([string]::IsNullOrWhiteSpace($inputValue)) {
    return $DefaultValue
  }
  return $inputValue.Trim().ToLowerInvariant().StartsWith("y")
}

function Resolve-Decision {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$ProvidedValue = "",
    [Parameter(Mandatory = $true)][string]$AutoValue,
    [Parameter(Mandatory = $true)][ValidateSet("auto", "ask")][string]$DecisionMode,
    [AllowEmptyCollection()][string[]]$Choices = @()
  )

  if (-not [string]::IsNullOrWhiteSpace($ProvidedValue)) {
    return $ProvidedValue
  }
  if ($DecisionMode -eq "auto") {
    return $AutoValue
  }
  return (Prompt-Choice -Name $Name -Choices $Choices -DefaultValue $AutoValue)
}

function Detect-Scenario {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot
  )

  $markers = @(
    "src",
    "app",
    "tests",
    "package.json",
    "pyproject.toml",
    "go.mod",
    "pom.xml",
    "build.gradle",
    "build.gradle.kts",
    "Cargo.toml"
  )
  foreach ($marker in $markers) {
    if (Test-Path (Join-Path $TargetRepoRoot $marker)) {
      return "brownfield"
    }
  }

  $fileCount = @(Get-ChildItem -Path $TargetRepoRoot -Force -File -ErrorAction SilentlyContinue).Count
  if ($fileCount -gt 0) {
    return "brownfield"
  }
  return "greenfield"
}

function Test-GitRepository {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot
  )

  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    return $false
  }

  try {
    $global:LASTEXITCODE = 0
    git -C $TargetRepoRoot rev-parse --is-inside-work-tree *> $null
    return (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -eq 0)
  } catch {
    return $false
  }
}

function Get-BlueprintRegistry {
  $registryPath = Join-Path $repoRoot "config\\blueprints\\registry.json"
  $registry = Read-SbkJsonFile -Path $registryPath
  if ($null -eq $registry) {
    throw "blueprint registry missing: $registryPath"
  }
  return $registry
}

function Resolve-AutoBlueprintName {
  param(
    [Parameter(Mandatory = $true)]$Registry,
    [Parameter(Mandatory = $true)][ValidateSet("greenfield", "brownfield")][string]$Scenario,
    [Parameter(Mandatory = $true)][ValidateSet("backend", "frontend", "fullstack")][string]$ProjectType,
    [Parameter(Mandatory = $true)][bool]$AllowBeta
  )

  $preferred = @()
  if ($ProjectType -eq "frontend") {
    $preferred = @("cli-tool", "api-service")
  } elseif ($ProjectType -eq "fullstack") {
    $preferred = @("monorepo-service", "api-service")
  } elseif ($Scenario -eq "brownfield") {
    $preferred = @("api-service", "worker-service")
  } else {
    $preferred = @("api-service", "worker-service")
  }

  foreach ($candidate in $preferred) {
    $entry = @($Registry.packs | Where-Object { [string]$_.name -eq $candidate } | Select-Object -First 1)
    if ($entry.Count -eq 0) {
      continue
    }
    $channel = [string]$entry[0].channel
    if ($channel.Equals("beta", [System.StringComparison]::OrdinalIgnoreCase) -and -not $AllowBeta) {
      continue
    }
    return $candidate
  }

  $stableFallback = @($Registry.packs | Where-Object {
      -not [string]::IsNullOrWhiteSpace([string]$_.name) -and
      ([string]$_.channel).Equals("stable", [System.StringComparison]::OrdinalIgnoreCase)
    } | Select-Object -First 1)
  if ($stableFallback.Count -gt 0) {
    return [string]$stableFallback[0].name
  }

  $first = @($Registry.packs | Select-Object -First 1)
  if ($first.Count -gt 0) {
    return [string]$first[0].name
  }
  return ""
}

function Read-RecommendedProfile {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot
  )

  $riskPath = Join-Path $TargetRepoRoot ".metrics\\intake-risk-profile.json"
  $risk = Read-SbkJsonFile -Path $riskPath
  if ($null -eq $risk) {
    return ""
  }
  $riskModel = Get-SbkPropertyValue -Object $risk -Name "riskModel"
  $recommended = [string](Get-SbkPropertyValue -Object $riskModel -Name "recommendedProfile")
  if ($recommended -in @("strict", "balanced", "lite")) {
    return $recommended
  }
  return ""
}

$script:Stages = New-Object 'System.Collections.Generic.List[object]'
$script:ShellCommand = Get-ShellCommand

function Invoke-Stage {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$ScriptName,
    [AllowEmptyCollection()][string[]]$ScriptArgs = @()
  )

  $stage = [ordered]@{
    name = $Name
    script = $ScriptName
    args = @($ScriptArgs)
    startedAt = [DateTimeOffset]::UtcNow.ToString("o")
    endedAt = ""
    status = "running"
    error = ""
  }

  try {
    Write-Host ("[flow] stage start: {0}" -f $Name)
    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    & $script:ShellCommand -ExecutionPolicy Bypass -File $scriptPath @ScriptArgs
    if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
      throw ("stage exited with code {0}" -f $LASTEXITCODE)
    }
    $stage.status = "passed"
    Write-Host ("[flow] stage passed: {0}" -f $Name)
  } catch {
    $stage.status = "failed"
    $stage.error = $_.Exception.Message
    Write-Host ("[flow] stage failed: {0} -> {1}" -f $Name, $_.Exception.Message)
    throw
  } finally {
    $stage.endedAt = [DateTimeOffset]::UtcNow.ToString("o")
    $script:Stages.Add([PSCustomObject]$stage) | Out-Null
  }
}

function Invoke-InlineStage {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Action
  )

  $stage = [ordered]@{
    name = $Name
    script = "inline"
    args = @()
    startedAt = [DateTimeOffset]::UtcNow.ToString("o")
    endedAt = ""
    status = "running"
    error = ""
  }

  try {
    Write-Host ("[flow] stage start: {0}" -f $Name)
    & $Action
    $stage.status = "passed"
    Write-Host ("[flow] stage passed: {0}" -f $Name)
  } catch {
    $stage.status = "failed"
    $stage.error = $_.Exception.Message
    Write-Host ("[flow] stage failed: {0} -> {1}" -f $Name, $_.Exception.Message)
    throw
  } finally {
    $stage.endedAt = [DateTimeOffset]::UtcNow.ToString("o")
    $script:Stages.Add([PSCustomObject]$stage) | Out-Null
  }
}

if ($null -eq $CommandArgs -or $CommandArgs.Count -eq 0) {
  Show-Usage
  exit 0
}

$operation = "run"
$rest = @($CommandArgs)
if ($CommandArgs.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$CommandArgs[0]) -and -not ([string]$CommandArgs[0]).StartsWith("--")) {
  $operation = [string]$CommandArgs[0]
  $rest = if ($CommandArgs.Count -gt 1) { @($CommandArgs[1..($CommandArgs.Count - 1)]) } else { @() }
}

if ($operation -in @("help", "-h", "--help")) {
  Show-Usage
  exit 0
}
if (-not $operation.Equals("run", [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "unknown flow operation: $operation"
}

$rest = @($rest)
if ($rest.Count -eq 1 -and [string]$rest[0] -in @("--help", "-h", "help")) {
  Show-Usage
  exit 0
}

$targetRepoRootRaw = "."
$decisionMode = "auto"
$scenarioInput = "auto"
$adapterInput = ""
$profileInput = ""
$projectNameInput = ""
$projectType = "fullstack"
$blueprintInput = ""
$allowBeta = $false
$channelInput = ""
$preset = "minimal"
$withInstall = $false
$skipVerify = $false
$fleetRootsRaw = ""
$force = $false

for ($i = 0; $i -lt $rest.Count; $i++) {
  $token = [string]$rest[$i]
  switch ($token) {
    "--target-repo-root" {
      if (($i + 1) -lt $rest.Count) { $targetRepoRootRaw = [string]$rest[$i + 1]; $i++ }
      continue
    }
    "--decision-mode" {
      if (($i + 1) -lt $rest.Count) { $decisionMode = [string]$rest[$i + 1]; $i++ }
      continue
    }
    "--scenario" {
      if (($i + 1) -lt $rest.Count) { $scenarioInput = [string]$rest[$i + 1]; $i++ }
      continue
    }
    "--adapter" {
      if (($i + 1) -lt $rest.Count) { $adapterInput = [string]$rest[$i + 1]; $i++ }
      continue
    }
    "--profile" {
      if (($i + 1) -lt $rest.Count) { $profileInput = [string]$rest[$i + 1]; $i++ }
      continue
    }
    "--project-name" {
      if (($i + 1) -lt $rest.Count) { $projectNameInput = [string]$rest[$i + 1]; $i++ }
      continue
    }
    "--project-type" {
      if (($i + 1) -lt $rest.Count) { $projectType = [string]$rest[$i + 1]; $i++ }
      continue
    }
    "--blueprint" {
      if (($i + 1) -lt $rest.Count) { $blueprintInput = [string]$rest[$i + 1]; $i++ }
      continue
    }
    "--allow-beta" {
      $allowBeta = $true
      continue
    }
    "--channel" {
      if (($i + 1) -lt $rest.Count) { $channelInput = [string]$rest[$i + 1]; $i++ }
      continue
    }
    "--preset" {
      if (($i + 1) -lt $rest.Count) { $preset = [string]$rest[$i + 1]; $i++ }
      continue
    }
    "--with-install" {
      $withInstall = $true
      continue
    }
    "--skip-verify" {
      $skipVerify = $true
      continue
    }
    "--fleet-roots" {
      if (($i + 1) -lt $rest.Count) { $fleetRootsRaw = [string]$rest[$i + 1]; $i++ }
      continue
    }
    "--force" {
      $force = $true
      continue
    }
    default {
      throw "unknown option for flow run: $token"
    }
  }
}

if ($decisionMode -notin @("auto", "ask")) {
  throw "decision-mode must be one of: auto, ask"
}
if ($scenarioInput -notin @("auto", "greenfield", "brownfield")) {
  throw "scenario must be one of: auto, greenfield, brownfield"
}
if ($projectType -notin @("backend", "frontend", "fullstack")) {
  throw "project-type must be one of: backend, frontend, fullstack"
}
if ($preset -notin @("minimal", "full")) {
  throw "preset must be one of: minimal, full"
}

$targetRepoRoot = Resolve-TargetRepoRoot -Path $targetRepoRootRaw
$detectedScenario = Detect-Scenario -TargetRepoRoot $targetRepoRoot
$scenarioAuto = if ($scenarioInput -eq "auto") { $detectedScenario } else { $scenarioInput }
$scenario = Resolve-Decision -Name "scenario" -ProvidedValue $(if ($scenarioInput -eq "auto") { "" } else { $scenarioInput }) -AutoValue $scenarioAuto -DecisionMode $decisionMode -Choices @("greenfield", "brownfield")

$runtimeForAdapter = Get-SbkRuntimeContext -SbkRoot $repoRoot -TargetRepoRoot $targetRepoRoot -AdapterOverride $adapterInput
$availableAdapters = @(Get-SbkAdapterManifests -AdaptersRoot (Resolve-SbkPath -BasePath $repoRoot -Path "config/adapters")) | ForEach-Object { [string](Get-SbkPropertyValue -Object $_ -Name "name") }
$adapterAuto = [string]$runtimeForAdapter.adapter
$adapter = Resolve-Decision -Name "adapter" -ProvidedValue $adapterInput -AutoValue $adapterAuto -DecisionMode $decisionMode -Choices $availableAdapters

$projectNameAuto = if ([string]::IsNullOrWhiteSpace($projectNameInput)) { Split-Path $targetRepoRoot -Leaf } else { $projectNameInput }
$projectName = if ([string]::IsNullOrWhiteSpace($projectNameInput) -and $decisionMode -eq "ask") {
  Resolve-Decision -Name "project-name" -ProvidedValue "" -AutoValue $projectNameAuto -DecisionMode "ask" -Choices @()
} else {
  $projectNameAuto
}

$runtimeConfigPath = Join-Path $targetRepoRoot "sbk.config.json"
$runtimeConfig = Read-SbkJsonFile -Path $runtimeConfigPath
$defaultChannel = [string](Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $runtimeConfig -Name "releaseChannels") -Name "defaultChannel")
if ([string]::IsNullOrWhiteSpace($defaultChannel)) {
  $defaultChannel = "stable"
}
$channel = Resolve-Decision -Name "channel" -ProvidedValue $channelInput -AutoValue $defaultChannel -DecisionMode $decisionMode -Choices @("stable", "beta")
if ($channel -eq "beta") {
  if ($decisionMode -eq "ask" -and -not $allowBeta) {
    $allowBeta = Prompt-Boolean -Name "allow beta blueprint/channel assets" -DefaultValue $true
  } else {
    $allowBeta = $true
  }
}

$flowStatus = "passed"
$flowError = ""
$blueprint = ""
$profile = ""

try {
  if ($withInstall) {
    $installArgs = @(
      "-TargetRepoRoot", $targetRepoRoot,
      "-Preset", $preset,
      "-Channel", $channel
    )
    if ($force) {
      $installArgs += "-Overwrite"
    }
    Invoke-Stage -Name ("install core ({0})" -f $channel) -ScriptName "sbk-install.ps1" -ScriptArgs $installArgs
  }

  $registry = Get-BlueprintRegistry
  $blueprintAuto = Resolve-AutoBlueprintName -Registry $registry -Scenario $scenario -ProjectType $projectType -AllowBeta $allowBeta
  $blueprintChoices = @($registry.packs | ForEach-Object { [string]$_.name }) + @("none")
  $blueprint = Resolve-Decision -Name "blueprint" -ProvidedValue $blueprintInput -AutoValue $blueprintAuto -DecisionMode $decisionMode -Choices $blueprintChoices

  if ($scenario -eq "greenfield") {
    $greenfieldArgs = @(
      "-Adapter", $adapter,
      "-ProjectName", $projectName,
      "-ProjectType", $projectType,
      "-TargetRepoRoot", $targetRepoRoot
    )
    if ($force) {
      $greenfieldArgs += "-Force"
    }
    Invoke-Stage -Name "greenfield bootstrap" -ScriptName "greenfield-bootstrap.ps1" -ScriptArgs $greenfieldArgs
  }

  if (-not [string]::IsNullOrWhiteSpace($blueprint) -and -not $blueprint.Equals("none", [System.StringComparison]::OrdinalIgnoreCase)) {
    $blueprintArgs = @(
      "apply",
      "--name", $blueprint,
      "--target-repo-root", $targetRepoRoot,
      "--project-name", $projectName,
      "--adapter", $adapter
    )
    if ($allowBeta) {
      $blueprintArgs += "--allow-beta"
    }
    $requiresBlueprintForce = $force -or $withInstall -or (Test-Path (Join-Path $targetRepoRoot ".github\\workflows\\ci.yml"))
    if ($requiresBlueprintForce) {
      $blueprintArgs += "--force"
    }
    Invoke-Stage -Name ("blueprint apply ({0})" -f $blueprint) -ScriptName "sbk-blueprint.ps1" -ScriptArgs $blueprintArgs
    Invoke-Stage -Name "blueprint verify" -ScriptName "sbk-blueprint.ps1" -ScriptArgs @("verify", "--target-repo-root", $targetRepoRoot)
  }

  if (-not (Test-GitRepository -TargetRepoRoot $targetRepoRoot)) {
    Invoke-InlineStage -Name "initialize git repository" -Action {
      $global:LASTEXITCODE = 0
      git -C $targetRepoRoot init *> $null
      if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
        throw ("git init failed with exit code {0}" -f $LASTEXITCODE)
      }
      git -C $targetRepoRoot config user.email "sbk-flow@example.local" *> $null
      git -C $targetRepoRoot config user.name "sbk-flow" *> $null
    }
  }

  Invoke-Stage -Name "intake analyze" -ScriptName "sbk-intake.ps1" -ScriptArgs @("analyze", "--target-repo-root", $targetRepoRoot)
  Invoke-Stage -Name "intake plan" -ScriptName "sbk-intake.ps1" -ScriptArgs @("plan", "--target-repo-root", $targetRepoRoot)

  $recommendedProfile = Read-RecommendedProfile -TargetRepoRoot $targetRepoRoot
  $profileAuto = if (-not [string]::IsNullOrWhiteSpace($recommendedProfile)) { $recommendedProfile } elseif ($scenario -eq "brownfield") { "balanced" } else { "strict" }
  $profile = Resolve-Decision -Name "profile" -ProvidedValue $profileInput -AutoValue $profileAuto -DecisionMode $decisionMode -Choices @("strict", "balanced", "lite")

  $verifyCandidates = @($profile)
  if ([string]::IsNullOrWhiteSpace($profileInput) -and $decisionMode -eq "auto") {
    if ($profile -eq "strict") {
      $verifyCandidates += @("balanced", "lite")
    } elseif ($profile -eq "balanced") {
      $verifyCandidates += @("lite")
    }
  }
  $verifyCandidates = @($verifyCandidates | Select-Object -Unique)

  $verifyPassed = $false
  $lastVerifyError = ""
  foreach ($candidateProfile in $verifyCandidates) {
    try {
      Invoke-Stage -Name ("intake verify ({0})" -f $candidateProfile) -ScriptName "sbk-intake.ps1" -ScriptArgs @("verify", "--target-repo-root", $targetRepoRoot, "--profile", $candidateProfile)
      $profile = $candidateProfile
      $verifyPassed = $true
      break
    } catch {
      $lastVerifyError = $_.Exception.Message
      Write-Host ("[flow] intake verify fallback: profile={0} failed, trying next candidate" -f $candidateProfile)
    }
  }
  if (-not $verifyPassed) {
    throw ("intake verify failed for all candidates: {0}" -f $lastVerifyError)
  }

  Invoke-Stage -Name "adapter doctor" -ScriptName "sbk-adapter.ps1" -ScriptArgs @("doctor", "--target-repo-root", $targetRepoRoot, "--adapter", $adapter, "--profile", $profile)

  if (-not $skipVerify) {
    Invoke-Stage -Name "verify fast" -ScriptName "verify-fast.ps1" -ScriptArgs @("-TargetRepoRoot", $targetRepoRoot, "-Adapter", $adapter, "-Profile", $profile)
  }

  if (-not [string]::IsNullOrWhiteSpace($fleetRootsRaw)) {
    Invoke-Stage -Name "fleet collect" -ScriptName "sbk-fleet.ps1" -ScriptArgs @("collect", "--roots", $fleetRootsRaw)
    Invoke-Stage -Name "fleet report" -ScriptName "sbk-fleet.ps1" -ScriptArgs @("report", "--format", "json")
    Invoke-Stage -Name "fleet doctor" -ScriptName "sbk-fleet.ps1" -ScriptArgs @("doctor")
  }
} catch {
  $flowStatus = "failed"
  $flowError = $_.Exception.Message
}

$metricsDir = Join-Path $targetRepoRoot ".metrics"
if (-not (Test-Path $metricsDir)) {
  New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
}
$stagesSnapshot = $script:Stages.ToArray()

$summary = [ordered]@{
  generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
  status = $flowStatus
  error = $flowError
  decisionMode = $decisionMode
  targetRepoRoot = $targetRepoRoot
  decisions = [ordered]@{
    scenario = $scenario
    adapter = $adapter
    profile = $profile
    blueprint = $blueprint
    channel = $channel
    allowBeta = $allowBeta
    withInstall = $withInstall
    skipVerify = $skipVerify
    fleetRoots = $fleetRootsRaw
  }
  stages = $stagesSnapshot
}

$reportPath = Join-Path $metricsDir "flow-run-report.json"
$reportMdPath = Join-Path $metricsDir "flow-run-report.md"
Set-Content -Path $reportPath -Value ($summary | ConvertTo-Json -Depth 20) -Encoding UTF8

$lines = @()
$lines += "# Flow Run Report"
$lines += ""
$lines += "- generated_at: $($summary.generatedAt)"
$lines += "- target_repo_root: $targetRepoRoot"
$lines += "- decision_mode: $decisionMode"
$lines += "- scenario: $scenario"
$lines += "- adapter: $adapter"
$lines += "- profile: $profile"
$lines += "- blueprint: $blueprint"
$lines += "- channel: $channel"
$lines += ""
$lines += "## Stage Results"
$lines += ""
$lines += "| Stage | Status | Error |"
$lines += "| --- | --- | --- |"
foreach ($stage in $summary.stages) {
  $errorText = [string]$stage.error
  if ([string]::IsNullOrWhiteSpace($errorText)) {
    $errorText = "none"
  }
  $lines += "| $($stage.name) | $($stage.status) | $errorText |"
}
Set-Content -Path $reportMdPath -Value $lines -Encoding UTF8

Write-Host ($summary | ConvertTo-Json -Depth 20)

if ($flowStatus -ne "passed") {
  throw ("flow run failed: {0}" -f $flowError)
}
