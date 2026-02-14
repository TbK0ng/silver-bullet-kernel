param(
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$CommandArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "common\\sbk-runtime.ps1")

function Show-Usage {
  Write-Host "sbk intake <operation> [args]"
  Write-Host ""
  Write-Host "Operations:"
  Write-Host "  analyze [--target-repo-root <path>]"
  Write-Host "  plan [--target-repo-root <path>]"
  Write-Host "  verify [--target-repo-root <path>] [--profile lite|balanced|strict]"
}

function Resolve-TargetRepoRoot {
  param(
    [Parameter(Mandatory = $true)][string]$Path
  )

  $resolved = Resolve-SbkPath -BasePath $repoRoot -Path $Path
  if (-not (Test-Path $resolved -PathType Container)) {
    throw "target repository path does not exist or is not a directory: $resolved"
  }
  return (Resolve-Path -LiteralPath $resolved).Path
}

function Ensure-MetricsDir {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot
  )

  $metricsDir = Join-Path $TargetRepoRoot ".metrics"
  if (-not (Test-Path $metricsDir)) {
    New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
  }
  return $metricsDir
}

function Test-GitRepo {
  param([Parameter(Mandatory = $true)][string]$TargetRepoRoot)

  git -C $TargetRepoRoot rev-parse --is-inside-work-tree *> $null
  return (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -eq 0)
}

function Get-FilesByPattern {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot,
    [Parameter(Mandatory = $true)][string[]]$IncludeExtensions
  )

  $ignoreDirs = @(
    ".git",
    "node_modules",
    ".venv",
    ".mypy_cache",
    ".pytest_cache",
    "dist",
    "build",
    "out",
    ".next",
    ".turbo"
  )

  $allFiles = @(Get-ChildItem -Path $TargetRepoRoot -Recurse -File -ErrorAction SilentlyContinue)
  $picked = @()
  foreach ($file in $allFiles) {
    $relative = ($file.FullName.Substring($TargetRepoRoot.Length)).TrimStart("\", "/")
    $normalized = $relative -replace "\\", "/"
    $ignored = $false
    foreach ($dir in $ignoreDirs) {
      if ($normalized.StartsWith("$dir/", [System.StringComparison]::OrdinalIgnoreCase)) {
        $ignored = $true
        break
      }
    }
    if ($ignored) {
      continue
    }

    $ext = [System.IO.Path]::GetExtension($file.Name).ToLowerInvariant()
    if ($IncludeExtensions -contains $ext) {
      $picked += [PSCustomObject]@{
        fullPath = $file.FullName
        relativePath = $normalized
        extension = $ext
      }
    }
  }

  return @($picked)
}

function Get-LanguageDistribution {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$CodeFiles
  )

  $mapping = @{
    ".ts" = "typescript"
    ".tsx" = "typescript"
    ".js" = "javascript"
    ".jsx" = "javascript"
    ".py" = "python"
    ".go" = "go"
    ".java" = "java"
    ".rs" = "rust"
    ".cs" = "csharp"
  }

  $bucket = @{}
  foreach ($file in $CodeFiles) {
    $language = if ($mapping.ContainsKey($file.extension)) { [string]$mapping[$file.extension] } else { [string]$file.extension.TrimStart(".") }
    if (-not $bucket.ContainsKey($language)) {
      $bucket[$language] = 0
    }
    $bucket[$language]++
  }

  $output = @()
  foreach ($entry in $bucket.GetEnumerator() | Sort-Object -Property Name) {
    $output += [ordered]@{
      language = $entry.Key
      files = [int]$entry.Value
    }
  }

  return @($output)
}

function Get-VerifyRunsFailureRate {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot
  )

  $path = Join-Path $TargetRepoRoot ".metrics\\verify-runs.jsonl"
  if (-not (Test-Path $path -PathType Leaf)) {
    return [ordered]@{
      available = $false
      total = 0
      failed = 0
      failureRate = 50
      rationale = "verify telemetry missing; using conservative default"
    }
  }

  $total = 0
  $failed = 0
  $lines = Get-Content -Path $path -Encoding UTF8
  foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) {
      continue
    }
    try {
      $entry = $line | ConvertFrom-Json
      $total++
      if ([string](Get-SbkPropertyValue -Object $entry -Name "status") -eq "failed") {
        $failed++
      }
    } catch {
      continue
    }
  }

  if ($total -eq 0) {
    return [ordered]@{
      available = $false
      total = 0
      failed = 0
      failureRate = 50
      rationale = "verify telemetry empty; using conservative default"
    }
  }

  $rate = [math]::Round(($failed / $total) * 100, 2)
  return [ordered]@{
    available = $true
    total = $total
    failed = $failed
    failureRate = $rate
    rationale = "computed from .metrics/verify-runs.jsonl"
  }
}

function Get-ChurnHotspots {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot
  )

  if (-not (Test-GitRepo -TargetRepoRoot $TargetRepoRoot)) {
    return [ordered]@{
      available = $false
      hotspots = @()
      riskScore = 55
      rationale = "git history unavailable; using conservative default"
    }
  }

  $files = @(git -C $TargetRepoRoot log --since="90 days ago" --name-only --pretty=format: |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

  $groups = @($files | Group-Object | Sort-Object Count -Descending)
  $top = @($groups | Select-Object -First 10 | ForEach-Object {
      [ordered]@{
        path = [string]$_.Name
        commitsTouched = [int]$_.Count
      }
    })

  $topTotal = 0
  foreach ($item in $top) {
    $topTotal += [int]$item.commitsTouched
  }

  $score = [math]::Min(100, [math]::Round(($topTotal / 3), 2))
  return [ordered]@{
    available = $true
    hotspots = $top
    riskScore = $score
    rationale = "top 10 touched files in last 90 days"
  }
}

function Get-SpecDriftRisk {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot
  )

  if (-not (Test-GitRepo -TargetRepoRoot $TargetRepoRoot)) {
    return [ordered]@{
      available = $false
      driftEvents = 0
      riskScore = 45
      rationale = "git history unavailable; using conservative default"
    }
  }

  $commitIds = @(git -C $TargetRepoRoot log --since="30 days ago" --format=%H -- src)
  if ($commitIds.Count -eq 0) {
    return [ordered]@{
      available = $true
      driftEvents = 0
      riskScore = 15
      rationale = "no src commits in last 30 days"
    }
  }

  $drift = 0
  foreach ($id in $commitIds) {
    $changed = @(git -C $TargetRepoRoot show --name-only --pretty=format: $id)
    $touchedSrc = @($changed | Where-Object { $_ -like "src/*" }).Count -gt 0
    $touchedSpecs = @($changed | Where-Object { $_ -like "openspec/specs/*" -or $_ -like "openspec/changes/*" -or $_ -like "docs/*" }).Count -gt 0
    if ($touchedSrc -and -not $touchedSpecs) {
      $drift++
    }
  }

  $score = [math]::Min(100, [math]::Round($drift * 15, 2))
  return [ordered]@{
    available = $true
    driftEvents = $drift
    riskScore = $score
    rationale = "src commits without spec/docs updates in last 30 days"
  }
}

function Get-OwnershipRisk {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot
  )

  if (-not (Test-GitRepo -TargetRepoRoot $TargetRepoRoot)) {
    return [ordered]@{
      available = $false
      topAuthorShare = 0
      contributors = 0
      riskScore = 55
      rationale = "git history unavailable; using conservative default"
    }
  }

  $rows = @(git -C $TargetRepoRoot shortlog -s -n --since="90 days ago" HEAD)
  if ($rows.Count -eq 0) {
    return [ordered]@{
      available = $true
      topAuthorShare = 0
      contributors = 0
      riskScore = 50
      rationale = "no commits in the last 90 days"
    }
  }

  $counts = @()
  foreach ($row in $rows) {
    $trimmed = [string]$row
    $parts = $trimmed -split "\s+", 2
    if ($parts.Count -lt 1) {
      continue
    }
    $value = 0
    if ([int]::TryParse($parts[0], [ref]$value)) {
      $counts += $value
    }
  }

  if ($counts.Count -eq 0) {
    return [ordered]@{
      available = $true
      topAuthorShare = 0
      contributors = 0
      riskScore = 50
      rationale = "unable to parse contributor distribution"
    }
  }

  $sum = ($counts | Measure-Object -Sum).Sum
  $top = ($counts | Sort-Object -Descending | Select-Object -First 1)
  $share = if ($sum -eq 0) { 0 } else { [math]::Round(($top / $sum) * 100, 2) }
  $score = [math]::Min(100, [math]::Round($share, 2))

  return [ordered]@{
    available = $true
    topAuthorShare = $share
    contributors = $counts.Count
    riskScore = $score
    rationale = "top committer concentration in last 90 days"
  }
}

function Get-DependencyRisk {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot
  )

  $signals = [ordered]@{
    hasNodeLock = Test-Path (Join-Path $TargetRepoRoot "package-lock.json")
    hasPnpmLock = Test-Path (Join-Path $TargetRepoRoot "pnpm-lock.yaml")
    hasYarnLock = Test-Path (Join-Path $TargetRepoRoot "yarn.lock")
    hasPoetryLock = Test-Path (Join-Path $TargetRepoRoot "poetry.lock")
    hasUvLock = Test-Path (Join-Path $TargetRepoRoot "uv.lock")
    hasGoSum = Test-Path (Join-Path $TargetRepoRoot "go.sum")
    hasCargoLock = Test-Path (Join-Path $TargetRepoRoot "Cargo.lock")
    hasSecurityPolicy = Test-Path (Join-Path $TargetRepoRoot "SECURITY.md")
    hasDependabot = Test-Path (Join-Path $TargetRepoRoot ".github\\dependabot.yml")
  }

  $score = 80
  if ($signals.hasNodeLock -or $signals.hasPnpmLock -or $signals.hasYarnLock -or $signals.hasPoetryLock -or $signals.hasUvLock -or $signals.hasGoSum -or $signals.hasCargoLock) {
    $score -= 25
  }
  if ($signals.hasSecurityPolicy) {
    $score -= 15
  }
  if ($signals.hasDependabot) {
    $score -= 10
  }

  if ($score -lt 10) {
    $score = 10
  }

  return [ordered]@{
    riskScore = [int]$score
    rationale = "lockfile/security/dependabot signal coverage"
    evidence = $signals
  }
}

function Get-IntakeThresholds {
  param(
    [Parameter(Mandatory = $true)]$RuntimeConfig,
    [Parameter(Mandatory = $true)]$WorkflowPolicyConfig
  )

  $defaults = [ordered]@{
    lite = [ordered]@{
      maxOverallRisk = 80
      maxDimensionRisk = 95
    }
    balanced = [ordered]@{
      maxOverallRisk = 65
      maxDimensionRisk = 80
    }
    strict = [ordered]@{
      maxOverallRisk = 45
      maxDimensionRisk = 60
      requiredArtifacts = @(
        "workflow-policy.json",
        "sbk.config.json",
        "openspec/specs",
        "docs"
      )
    }
  }

  $thresholds = $defaults
  $fromRuntime = Get-SbkPropertyValue -Object $RuntimeConfig -Name "intake"
  $runtimeThresholds = Get-SbkPropertyValue -Object $fromRuntime -Name "thresholds"
  $policyThresholds = Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $WorkflowPolicyConfig -Name "intakeGate") -Name "thresholds"

  foreach ($source in @($policyThresholds, $runtimeThresholds)) {
    if ($null -eq $source) {
      continue
    }
    foreach ($profileName in @("lite", "balanced", "strict")) {
      $profileOverride = Get-SbkPropertyValue -Object $source -Name $profileName
      if ($null -eq $profileOverride) {
        continue
      }
      foreach ($property in $profileOverride.PSObject.Properties) {
        $thresholds[$profileName][$property.Name] = $property.Value
      }
    }
  }

  return $thresholds
}

function Get-RiskTier {
  param([Parameter(Mandatory = $true)][double]$Score)

  if ($Score -ge 75) { return "critical" }
  if ($Score -ge 60) { return "high" }
  if ($Score -ge 40) { return "moderate" }
  return "low"
}

function Invoke-Analyze {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot,
    [Parameter(Mandatory = $true)]$RuntimeConfig,
    [Parameter(Mandatory = $true)]$WorkflowPolicyConfig
  )

  $codeExtensions = @(".ts", ".tsx", ".js", ".jsx", ".py", ".go", ".java", ".rs")
  $codeFiles = @(Get-FilesByPattern -TargetRepoRoot $TargetRepoRoot -IncludeExtensions $codeExtensions)
  $testFiles = @($codeFiles | Where-Object {
      $_.relativePath -match "(^|/)(tests?|__tests__)/" -or $_.relativePath -match "\.(test|spec)\."
    })
  $languageDistribution = @(Get-LanguageDistribution -CodeFiles $codeFiles)

  $verifyFailure = Get-VerifyRunsFailureRate -TargetRepoRoot $TargetRepoRoot
  $churn = Get-ChurnHotspots -TargetRepoRoot $TargetRepoRoot
  $drift = Get-SpecDriftRisk -TargetRepoRoot $TargetRepoRoot
  $ownership = Get-OwnershipRisk -TargetRepoRoot $TargetRepoRoot
  $dependency = Get-DependencyRisk -TargetRepoRoot $TargetRepoRoot

  $testCoverageRatio = if ($codeFiles.Count -eq 0) {
    0
  } else {
    [math]::Round(($testFiles.Count / $codeFiles.Count) * 100, 2)
  }
  $testStructureRisk = [math]::Min(100, [math]::Round(100 - $testCoverageRatio, 2))
  $testReliabilityRisk = [math]::Round((0.6 * $testStructureRisk) + (0.4 * [double]$verifyFailure.failureRate), 2)

  $dimensions = @(
    [ordered]@{
      id = "testReliability"
      score = $testReliabilityRisk
      weight = 0.25
      rationale = "test ratio and verify failure signal"
      evidence = [ordered]@{
        codeFiles = $codeFiles.Count
        testFiles = $testFiles.Count
        testCoverageRatio = $testCoverageRatio
        verifyFailureRate = $verifyFailure.failureRate
      }
    },
    [ordered]@{
      id = "changeChurnHotspots"
      score = [double]$churn.riskScore
      weight = 0.2
      rationale = [string]$churn.rationale
      evidence = [ordered]@{
        hotspots = $churn.hotspots
      }
    },
    [ordered]@{
      id = "dependencyFreshnessSecurity"
      score = [double]$dependency.riskScore
      weight = 0.2
      rationale = [string]$dependency.rationale
      evidence = $dependency.evidence
    },
    [ordered]@{
      id = "specDocDrift"
      score = [double]$drift.riskScore
      weight = 0.2
      rationale = [string]$drift.rationale
      evidence = [ordered]@{
        driftEvents = $drift.driftEvents
      }
    },
    [ordered]@{
      id = "ownershipConcentration"
      score = [double]$ownership.riskScore
      weight = 0.15
      rationale = [string]$ownership.rationale
      evidence = [ordered]@{
        topAuthorShare = $ownership.topAuthorShare
        contributors = $ownership.contributors
      }
    }
  )

  $weighted = 0.0
  foreach ($dimension in $dimensions) {
    $weighted += ([double]$dimension.score * [double]$dimension.weight)
  }
  $overall = [math]::Round($weighted, 2)

  $thresholds = Get-IntakeThresholds -RuntimeConfig $RuntimeConfig -WorkflowPolicyConfig $WorkflowPolicyConfig
  $recommendedProfile = "strict"
  if ($overall -gt [double]$thresholds.strict.maxOverallRisk) {
    $recommendedProfile = "balanced"
  }
  if ($overall -gt [double]$thresholds.balanced.maxOverallRisk) {
    $recommendedProfile = "lite"
  }

  return [ordered]@{
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    targetRepoRoot = $TargetRepoRoot
    architecture = [ordered]@{
      codeFiles = $codeFiles.Count
      testFiles = $testFiles.Count
      languageDistribution = $languageDistribution
      topDirectories = @(
        Get-ChildItem -Path $TargetRepoRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name |
        Select-Object -First 20 |
        ForEach-Object { $_.Name }
      )
    }
    riskModel = [ordered]@{
      dimensions = $dimensions
      overallRiskScore = $overall
      riskTier = Get-RiskTier -Score $overall
      recommendedProfile = $recommendedProfile
      thresholds = $thresholds
    }
  }
}

function Write-AnalyzeArtifacts {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot,
    [Parameter(Mandatory = $true)]$Analysis
  )

  $metricsDir = Ensure-MetricsDir -TargetRepoRoot $TargetRepoRoot
  $architectureJsonPath = Join-Path $metricsDir "intake-architecture-map.json"
  $architectureMdPath = Join-Path $metricsDir "intake-architecture-map.md"
  $riskJsonPath = Join-Path $metricsDir "intake-risk-profile.json"
  $riskMdPath = Join-Path $metricsDir "intake-risk-profile.md"

  $architecturePayload = [ordered]@{
    generatedAt = $Analysis.generatedAt
    targetRepoRoot = $Analysis.targetRepoRoot
    architecture = $Analysis.architecture
  }
  $riskPayload = [ordered]@{
    generatedAt = $Analysis.generatedAt
    targetRepoRoot = $Analysis.targetRepoRoot
    riskModel = $Analysis.riskModel
  }

  Set-Content -Path $architectureJsonPath -Value ($architecturePayload | ConvertTo-Json -Depth 20) -Encoding UTF8
  Set-Content -Path $riskJsonPath -Value ($riskPayload | ConvertTo-Json -Depth 20) -Encoding UTF8

  $architectureLines = @()
  $architectureLines += "# Intake Architecture Map"
  $architectureLines += ""
  $architectureLines += "- generated_at_utc: $([DateTimeOffset]::UtcNow.ToString("u"))"
  $architectureLines += "- target_repo_root: $TargetRepoRoot"
  $architectureLines += "- code_files: $($Analysis.architecture.codeFiles)"
  $architectureLines += "- test_files: $($Analysis.architecture.testFiles)"
  $architectureLines += ""
  $architectureLines += "## Language Distribution"
  $architectureLines += ""
  foreach ($row in @($Analysis.architecture.languageDistribution)) {
    $architectureLines += "- $($row.language): $($row.files)"
  }
  $architectureLines += ""
  $architectureLines += "## Top Directories"
  $architectureLines += ""
  foreach ($dir in @($Analysis.architecture.topDirectories)) {
    $architectureLines += "- $dir"
  }

  $riskLines = @()
  $riskLines += "# Intake Risk Profile"
  $riskLines += ""
  $riskLines += "- overall_risk_score: $($Analysis.riskModel.overallRiskScore)"
  $riskLines += "- risk_tier: $($Analysis.riskModel.riskTier)"
  $riskLines += "- recommended_profile: $($Analysis.riskModel.recommendedProfile)"
  $riskLines += ""
  $riskLines += "## Dimensions"
  $riskLines += ""
  $riskLines += "| Dimension | Score | Weight | Rationale |"
  $riskLines += "| --- | ---: | ---: | --- |"
  foreach ($dimension in @($Analysis.riskModel.dimensions)) {
    $riskLines += "| $($dimension.id) | $($dimension.score) | $($dimension.weight) | $($dimension.rationale) |"
  }

  Set-Content -Path $architectureMdPath -Value $architectureLines -Encoding UTF8
  Set-Content -Path $riskMdPath -Value $riskLines -Encoding UTF8
}

function Read-ExistingRiskProfile {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot
  )

  $path = Join-Path $TargetRepoRoot ".metrics\\intake-risk-profile.json"
  return Read-SbkJsonFile -Path $path
}

function Invoke-Plan {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot,
    [Parameter(Mandatory = $true)]$RiskProfile
  )

  $riskModel = Get-SbkPropertyValue -Object $RiskProfile -Name "riskModel"
  $thresholds = Get-SbkPropertyValue -Object $riskModel -Name "thresholds"
  $overall = [double](Get-SbkPropertyValue -Object $riskModel -Name "overallRiskScore")
  $dimensions = @((Get-SbkPropertyValue -Object $riskModel -Name "dimensions") | ForEach-Object { $_ })

  $phases = @()
  foreach ($profile in @("lite", "balanced", "strict")) {
    $profileThreshold = Get-SbkPropertyValue -Object $thresholds -Name $profile
    $maxOverall = [double](Get-SbkPropertyValue -Object $profileThreshold -Name "maxOverallRisk")
    $maxDimension = [double](Get-SbkPropertyValue -Object $profileThreshold -Name "maxDimensionRisk")
    $requiredArtifacts = @((Get-SbkPropertyValue -Object $profileThreshold -Name "requiredArtifacts") | ForEach-Object { [string]$_ })

    $dimensionBlockers = @()
    foreach ($dimension in $dimensions) {
      if ([double]$dimension.score -gt $maxDimension) {
        $dimensionBlockers += "$($dimension.id):$($dimension.score)>$maxDimension"
      }
    }

    $overallBlocker = if ($overall -gt $maxOverall) {
      "overall:$overall>$maxOverall"
    } else {
      ""
    }

    $blockers = @($dimensionBlockers)
    if (-not [string]::IsNullOrWhiteSpace($overallBlocker)) {
      $blockers += $overallBlocker
    }

    $phases += [ordered]@{
      profile = $profile
      entryCriteria = [ordered]@{
        maxOverallRisk = $maxOverall
        maxDimensionRisk = $maxDimension
      }
      requiredArtifacts = $requiredArtifacts
      verifyCommands = @(
        "sbk intake verify --profile $profile --target-repo-root `"$TargetRepoRoot`"",
        "npm run verify:fast",
        "npm run workflow:policy"
      )
      blockers = $blockers
      ready = ($blockers.Count -eq 0)
    }
  }

  $recommendedStage = "strict"
  $strictPhase = @($phases | Where-Object { $_.profile -eq "strict" } | Select-Object -First 1)
  if ($strictPhase.Count -eq 0 -or -not [bool]$strictPhase[0].ready) {
    $recommendedStage = "balanced"
  }
  $balancedPhase = @($phases | Where-Object { $_.profile -eq "balanced" } | Select-Object -First 1)
  if ($balancedPhase.Count -eq 0 -or -not [bool]$balancedPhase[0].ready) {
    $recommendedStage = "lite"
  }

  return [ordered]@{
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    targetRepoRoot = $TargetRepoRoot
    currentOverallRiskScore = $overall
    recommendedStage = $recommendedStage
    phases = $phases
  }
}

function Write-PlanArtifacts {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot,
    [Parameter(Mandatory = $true)]$Plan
  )

  $metricsDir = Ensure-MetricsDir -TargetRepoRoot $TargetRepoRoot
  $jsonPath = Join-Path $metricsDir "intake-hardening-plan.json"
  $mdPath = Join-Path $metricsDir "intake-hardening-plan.md"

  Set-Content -Path $jsonPath -Value ($Plan | ConvertTo-Json -Depth 20) -Encoding UTF8

  $lines = @()
  $lines += "# Intake Hardening Plan"
  $lines += ""
  $lines += "- generated_at_utc: $([DateTimeOffset]::UtcNow.ToString("u"))"
  $lines += "- current_overall_risk_score: $($Plan.currentOverallRiskScore)"
  $lines += "- recommended_stage: $($Plan.recommendedStage)"
  $lines += ""
  foreach ($phase in @($Plan.phases)) {
    $lines += "## Phase: $($phase.profile)"
    $lines += ""
    $lines += "- entry_max_overall_risk: $($phase.entryCriteria.maxOverallRisk)"
    $lines += "- entry_max_dimension_risk: $($phase.entryCriteria.maxDimensionRisk)"
    $lines += "- ready: $($phase.ready)"
    $lines += "- blockers: $(if ($phase.blockers.Count -eq 0) { "none" } else { $phase.blockers -join ", " })"
    $lines += "- verify:"
    foreach ($command in @($phase.verifyCommands)) {
      $lines += "  - $command"
    }
    if ($phase.requiredArtifacts.Count -gt 0) {
      $lines += "- required_artifacts:"
      foreach ($artifact in @($phase.requiredArtifacts)) {
        $lines += "  - $artifact"
      }
    }
    $lines += ""
  }

  Set-Content -Path $mdPath -Value $lines -Encoding UTF8
}

function Invoke-Verify {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot,
    [Parameter(Mandatory = $true)][string]$Profile,
    [Parameter(Mandatory = $true)]$RiskProfile,
    [Parameter(Mandatory = $true)]$Plan
  )

  $riskModel = Get-SbkPropertyValue -Object $RiskProfile -Name "riskModel"
  $overall = [double](Get-SbkPropertyValue -Object $riskModel -Name "overallRiskScore")
  $dimensions = @((Get-SbkPropertyValue -Object $riskModel -Name "dimensions") | ForEach-Object { $_ })
  $threshold = Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $riskModel -Name "thresholds") -Name $Profile
  if ($null -eq $threshold) {
    throw "missing threshold for profile '$Profile'"
  }

  $maxOverall = [double](Get-SbkPropertyValue -Object $threshold -Name "maxOverallRisk")
  $maxDimension = [double](Get-SbkPropertyValue -Object $threshold -Name "maxDimensionRisk")
  $requiredArtifacts = @((Get-SbkPropertyValue -Object $threshold -Name "requiredArtifacts") | ForEach-Object { [string]$_ })

  $violations = @()
  if ($overall -gt $maxOverall) {
    $violations += "overall risk $overall exceeds max $maxOverall"
  }
  foreach ($dimension in $dimensions) {
    if ([double]$dimension.score -gt $maxDimension) {
      $violations += "dimension '$($dimension.id)' score $($dimension.score) exceeds max $maxDimension"
    }
  }

  foreach ($artifact in $requiredArtifacts) {
    $path = Join-Path $TargetRepoRoot ($artifact -replace "/", "\")
    if (-not (Test-Path $path)) {
      $violations += "required artifact missing: $artifact"
    }
  }

  $phase = @((Get-SbkPropertyValue -Object $Plan -Name "phases") | ForEach-Object { $_ } | Where-Object { [string]$_.profile -eq $Profile } | Select-Object -First 1)
  if ($phase.Count -gt 0 -and [bool]$phase[0].blockers.Count -gt 0) {
    foreach ($blocker in @($phase[0].blockers)) {
      $violations += "plan blocker: $blocker"
    }
  }

  return [ordered]@{
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    profile = $Profile
    targetRepoRoot = $TargetRepoRoot
    overallRisk = $overall
    maxOverallRisk = $maxOverall
    maxDimensionRisk = $maxDimension
    requiredArtifacts = $requiredArtifacts
    passed = ($violations.Count -eq 0)
    violations = $violations
    remediation = if ($violations.Count -eq 0) {
      @("none")
    } else {
      @(
        "Run `sbk intake analyze --target-repo-root `"$TargetRepoRoot`"` to refresh risk profile.",
        "Run `sbk intake plan --target-repo-root `"$TargetRepoRoot`"` and resolve blockers.",
        "Address missing artifacts and high-risk dimensions, then re-run `sbk intake verify`."
      )
    }
  }
}

function Write-VerifyArtifacts {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot,
    [Parameter(Mandatory = $true)]$Verification
  )

  $metricsDir = Ensure-MetricsDir -TargetRepoRoot $TargetRepoRoot
  $jsonPath = Join-Path $metricsDir "intake-readiness.json"
  $mdPath = Join-Path $metricsDir "intake-readiness.md"

  Set-Content -Path $jsonPath -Value ($Verification | ConvertTo-Json -Depth 20) -Encoding UTF8

  $lines = @()
  $lines += "# Intake Readiness"
  $lines += ""
  $lines += "- generated_at_utc: $([DateTimeOffset]::UtcNow.ToString("u"))"
  $lines += "- profile: $($Verification.profile)"
  $lines += "- passed: $($Verification.passed)"
  $lines += "- overall_risk: $($Verification.overallRisk)"
  $lines += "- max_overall_risk: $($Verification.maxOverallRisk)"
  $lines += ""
  $lines += "## Violations"
  $lines += ""
  if ($Verification.violations.Count -eq 0) {
    $lines += "- none"
  } else {
    foreach ($violation in @($Verification.violations)) {
      $lines += "- $violation"
    }
  }
  $lines += ""
  $lines += "## Remediation"
  $lines += ""
  foreach ($item in @($Verification.remediation)) {
    $lines += "- $item"
  }

  Set-Content -Path $mdPath -Value $lines -Encoding UTF8
}

if ($null -eq $CommandArgs -or $CommandArgs.Count -eq 0) {
  Show-Usage
  exit 0
}

$operation = [string]$CommandArgs[0]
$rest = @()
if ($CommandArgs.Count -gt 1) {
  $rest = @($CommandArgs[1..($CommandArgs.Count - 1)])
}

$targetRepoRootRaw = "."
$profile = "strict"
for ($i = 0; $i -lt $rest.Count; $i++) {
  $token = [string]$rest[$i]
  if ($token -eq "--target-repo-root" -and ($i + 1) -lt $rest.Count) {
    $targetRepoRootRaw = [string]$rest[$i + 1]
    $i++
    continue
  }
  if ($token -eq "--profile" -and ($i + 1) -lt $rest.Count) {
    $profile = [string]$rest[$i + 1]
    $i++
    continue
  }
}

$targetRepoRoot = Resolve-TargetRepoRoot -Path $targetRepoRootRaw
$runtimeConfig = Read-SbkJsonFile -Path (Join-Path $targetRepoRoot "sbk.config.json")
if ($null -eq $runtimeConfig) {
  $runtimeConfig = Read-SbkJsonFile -Path (Join-Path $repoRoot "sbk.config.json")
}
$workflowPolicy = Read-SbkJsonFile -Path (Join-Path $targetRepoRoot "workflow-policy.json")
if ($null -eq $workflowPolicy) {
  $workflowPolicy = Read-SbkJsonFile -Path (Join-Path $repoRoot "workflow-policy.json")
}
if ($null -eq $workflowPolicy) {
  $workflowPolicy = [PSCustomObject]@{}
}

switch ($operation.ToLowerInvariant()) {
  "analyze" {
    $analysis = Invoke-Analyze `
      -TargetRepoRoot $targetRepoRoot `
      -RuntimeConfig $runtimeConfig `
      -WorkflowPolicyConfig $workflowPolicy
    Write-AnalyzeArtifacts -TargetRepoRoot $targetRepoRoot -Analysis $analysis
    Write-Host ("[intake] analyze target={0} overall_risk={1} recommended_profile={2}" -f $targetRepoRoot, $analysis.riskModel.overallRiskScore, $analysis.riskModel.recommendedProfile)
    break
  }
  "plan" {
    $riskProfile = Read-ExistingRiskProfile -TargetRepoRoot $targetRepoRoot
    if ($null -eq $riskProfile) {
      $analysis = Invoke-Analyze `
        -TargetRepoRoot $targetRepoRoot `
        -RuntimeConfig $runtimeConfig `
        -WorkflowPolicyConfig $workflowPolicy
      Write-AnalyzeArtifacts -TargetRepoRoot $targetRepoRoot -Analysis $analysis
      $riskProfile = [ordered]@{
        generatedAt = $analysis.generatedAt
        targetRepoRoot = $analysis.targetRepoRoot
        riskModel = $analysis.riskModel
      }
    }
    $plan = Invoke-Plan -TargetRepoRoot $targetRepoRoot -RiskProfile $riskProfile
    Write-PlanArtifacts -TargetRepoRoot $targetRepoRoot -Plan $plan
    Write-Host ("[intake] plan target={0} recommended_stage={1}" -f $targetRepoRoot, $plan.recommendedStage)
    break
  }
  "verify" {
    if ($profile -notin @("lite", "balanced", "strict")) {
      throw "verify profile must be one of: lite, balanced, strict"
    }

    $riskProfile = Read-ExistingRiskProfile -TargetRepoRoot $targetRepoRoot
    if ($null -eq $riskProfile) {
      $analysis = Invoke-Analyze `
        -TargetRepoRoot $targetRepoRoot `
        -RuntimeConfig $runtimeConfig `
        -WorkflowPolicyConfig $workflowPolicy
      Write-AnalyzeArtifacts -TargetRepoRoot $targetRepoRoot -Analysis $analysis
      $riskProfile = [ordered]@{
        generatedAt = $analysis.generatedAt
        targetRepoRoot = $analysis.targetRepoRoot
        riskModel = $analysis.riskModel
      }
    }

    $planPath = Join-Path $targetRepoRoot ".metrics\\intake-hardening-plan.json"
    $plan = Read-SbkJsonFile -Path $planPath
    if ($null -eq $plan) {
      $plan = Invoke-Plan -TargetRepoRoot $targetRepoRoot -RiskProfile $riskProfile
      Write-PlanArtifacts -TargetRepoRoot $targetRepoRoot -Plan $plan
    }

    $verification = Invoke-Verify `
      -TargetRepoRoot $targetRepoRoot `
      -Profile $profile `
      -RiskProfile $riskProfile `
      -Plan $plan
    Write-VerifyArtifacts -TargetRepoRoot $targetRepoRoot -Verification $verification
    Write-Host ("[intake] verify profile={0} passed={1}" -f $profile, $verification.passed)
    if (-not [bool]$verification.passed) {
      throw "intake verify failed: strict prerequisites are not satisfied"
    }
    break
  }
  default {
    throw "unknown intake operation: $operation"
  }
}
