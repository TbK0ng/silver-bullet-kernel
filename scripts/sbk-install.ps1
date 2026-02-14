param(
  [string]$TargetRepoRoot = ".",
  [ValidateSet("minimal", "full")][string]$Preset = "full",
  [ValidateSet("stable", "beta")][string]$Channel = "stable",
  [switch]$Overwrite,
  [switch]$SkipPackageScriptInjection
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sbkRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$targetRoot = if ([System.IO.Path]::IsPathRooted($TargetRepoRoot)) {
  $resolved = Resolve-Path -LiteralPath $TargetRepoRoot -ErrorAction SilentlyContinue
  if ($null -ne $resolved) { $resolved.Path } else { $TargetRepoRoot }
} else {
  Resolve-Path (Join-Path $sbkRoot ($TargetRepoRoot -replace "/", "\")) | Select-Object -ExpandProperty Path
}

if (-not (Test-Path $targetRoot)) {
  throw "target repository path does not exist: $targetRoot"
}

$stats = @{
  copied = 0
  overwritten = 0
  skipped = 0
}

function Normalize-RelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$Path
  )

  return ($Path -replace "\\", "/").Trim("/")
}

function Parse-SemVer {
  param(
    [Parameter(Mandatory = $true)][string]$Version
  )

  $regex = "^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)(?:-(?<prerelease>[0-9A-Za-z\.-]+))?$"
  $match = [regex]::Match($Version, $regex)
  if (-not $match.Success) {
    throw "invalid semantic version: $Version"
  }

  return [PSCustomObject]@{
    major = [int]$match.Groups["major"].Value
    minor = [int]$match.Groups["minor"].Value
    patch = [int]$match.Groups["patch"].Value
    prerelease = [string]$match.Groups["prerelease"].Value
  }
}

function Compare-SemVer {
  param(
    [Parameter(Mandatory = $true)][string]$Left,
    [Parameter(Mandatory = $true)][string]$Right
  )

  $l = Parse-SemVer -Version $Left
  $r = Parse-SemVer -Version $Right

  foreach ($property in @("major", "minor", "patch")) {
    if ($l.$property -lt $r.$property) {
      return -1
    }
    if ($l.$property -gt $r.$property) {
      return 1
    }
  }

  if ([string]::IsNullOrWhiteSpace($l.prerelease) -and [string]::IsNullOrWhiteSpace($r.prerelease)) {
    return 0
  }
  if ([string]::IsNullOrWhiteSpace($l.prerelease) -and -not [string]::IsNullOrWhiteSpace($r.prerelease)) {
    return 1
  }
  if (-not [string]::IsNullOrWhiteSpace($l.prerelease) -and [string]::IsNullOrWhiteSpace($r.prerelease)) {
    return -1
  }

  return [string]::Compare($l.prerelease, $r.prerelease, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-ReleaseManifest {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][ValidateSet("stable", "beta")][string]$SelectedChannel
  )

  $path = Join-Path $Root ("config\\release\\channels\\{0}.json" -f $SelectedChannel)
  if (-not (Test-Path $path -PathType Leaf)) {
    throw "release manifest missing: $path"
  }
  $manifest = Get-Content -Path $path -Encoding UTF8 -Raw | ConvertFrom-Json
  if ($null -eq $manifest) {
    throw "invalid release manifest: $path"
  }
  return [PSCustomObject]@{
    path = $path
    value = $manifest
  }
}

function Read-TargetReleaseManifest {
  param(
    [Parameter(Mandatory = $true)][string]$Root
  )

  $path = Join-Path $Root ".sbk\\release-manifest.json"
  if (-not (Test-Path $path -PathType Leaf)) {
    return $null
  }

  $manifest = Get-Content -Path $path -Encoding UTF8 -Raw | ConvertFrom-Json
  if ($null -eq $manifest) {
    return $null
  }
  return [PSCustomObject]@{
    path = $path
    value = $manifest
  }
}

function Test-ChannelCompatibility {
  param(
    [Parameter(Mandatory = $true)]$CurrentManifest,
    [Parameter(Mandatory = $false)]$PreviousManifest
  )

  if ($null -eq $PreviousManifest) {
    return [PSCustomObject]@{
      safe = $true
      reason = "initial channel bootstrap"
    }
  }

  $currentChannel = [string]$CurrentManifest.channel
  $currentVersion = [string]$CurrentManifest.version
  $previousChannel = [string]$PreviousManifest.channel
  $previousVersion = [string]$PreviousManifest.version

  $compatibility = $CurrentManifest.compatibility
  $allowChannels = @($compatibility.allowFromChannels | ForEach-Object { [string]$_ })
  if ($allowChannels.Count -gt 0 -and -not ($allowChannels -contains $previousChannel)) {
    return [PSCustomObject]@{
      safe = $false
      reason = ("channel transition blocked: {0} -> {1}" -f $previousChannel, $currentChannel)
    }
  }

  $allowMajors = @($compatibility.allowFromMajor | ForEach-Object { [int]$_ })
  $previousParsed = Parse-SemVer -Version $previousVersion
  if ($allowMajors.Count -gt 0 -and -not ($allowMajors -contains $previousParsed.major)) {
    return [PSCustomObject]@{
      safe = $false
      reason = ("major compatibility blocked: from {0} (major={1})" -f $previousVersion, $previousParsed.major)
    }
  }

  $minFromVersion = [string]$compatibility.minFromVersion
  if (-not [string]::IsNullOrWhiteSpace($minFromVersion)) {
    if ((Compare-SemVer -Left $previousVersion -Right $minFromVersion) -lt 0) {
      return [PSCustomObject]@{
        safe = $false
        reason = ("minimum compatible source version is {0}, but current target is {1}" -f $minFromVersion, $previousVersion)
      }
    }
  }

  if ($previousChannel.Equals($currentChannel, [System.StringComparison]::OrdinalIgnoreCase)) {
    if ((Compare-SemVer -Left $currentVersion -Right $previousVersion) -lt 0) {
      return [PSCustomObject]@{
        safe = $false
        reason = ("version downgrade blocked within channel {0}: {1} -> {2}" -f $currentChannel, $previousVersion, $currentVersion)
      }
    }
  }

  return [PSCustomObject]@{
    safe = $true
    reason = "channel transition is compatible"
  }
}

function Write-ReleaseAudit {
  param(
    [Parameter(Mandatory = $true)][string]$DestinationRoot,
    [Parameter(Mandatory = $true)]$CurrentManifest,
    [Parameter(Mandatory = $false)]$PreviousManifest,
    [Parameter(Mandatory = $true)]$Compatibility
  )

  $sbkDir = Join-Path $DestinationRoot ".sbk"
  if (-not (Test-Path $sbkDir)) {
    New-Item -ItemType Directory -Path $sbkDir -Force | Out-Null
  }
  $metricsDir = Join-Path $DestinationRoot ".metrics"
  if (-not (Test-Path $metricsDir)) {
    New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
  }

  $previousSummary = $null
  if ($null -ne $PreviousManifest) {
    $previousPublishedAt = ""
    $publishedProperty = $PreviousManifest.PSObject.Properties | Where-Object { $_.Name -eq "publishedAt" } | Select-Object -First 1
    if ($null -ne $publishedProperty) {
      $previousPublishedAt = [string]$publishedProperty.Value
    } else {
      $generatedProperty = $PreviousManifest.PSObject.Properties | Where-Object { $_.Name -eq "generatedAt" } | Select-Object -First 1
      if ($null -ne $generatedProperty) {
        $previousPublishedAt = [string]$generatedProperty.Value
      }
    }

    $previousSummary = [ordered]@{
      channel = [string]$PreviousManifest.channel
      version = [string]$PreviousManifest.version
      publishedAt = $previousPublishedAt
    }
  }

  $rollout = [ordered]@{
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    channel = [string]$CurrentManifest.channel
    version = [string]$CurrentManifest.version
    manifestName = [string]$CurrentManifest.name
    previous = $previousSummary
    transition = [ordered]@{
      safe = [bool]$Compatibility.safe
      reason = [string]$Compatibility.reason
      fromChannel = if ($null -eq $previousSummary) { "" } else { [string]$previousSummary.channel }
      toChannel = [string]$CurrentManifest.channel
      fromVersion = if ($null -eq $previousSummary) { "" } else { [string]$previousSummary.version }
      toVersion = [string]$CurrentManifest.version
    }
    migrationNotes = @($CurrentManifest.migrationNotes | ForEach-Object { [string]$_ })
  }

  $manifestPath = Join-Path $sbkDir "release-manifest.json"
  Set-Content -Path $manifestPath -Value ($rollout | ConvertTo-Json -Depth 20) -Encoding UTF8

  $auditPath = Join-Path $metricsDir "channel-rollout-audit.jsonl"
  Add-Content -Path $auditPath -Value ($rollout | ConvertTo-Json -Depth 20)
}

function Resolve-SourceFile {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )

  $sourcePath = Join-Path $Root ($RelativePath -replace "/", "\")
  if (Test-Path $sourcePath -PathType Leaf) {
    return (Resolve-Path $sourcePath).Path
  }
  return $null
}

function Get-FilesFromRelativeDirectory {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$RelativeDirectory
  )

  $directoryPath = Join-Path $Root ($RelativeDirectory -replace "/", "\")
  if (-not (Test-Path $directoryPath -PathType Container)) {
    return @()
  }

  $files = @()
  $resolvedDir = (Resolve-Path $directoryPath).Path
  foreach ($item in Get-ChildItem -Path $resolvedDir -Recurse -File) {
    $relative = Normalize-RelativePath -Path ($item.FullName.Substring($Root.Length).TrimStart("\", "/"))
    $files += [PSCustomObject]@{
      source = $item.FullName
      relative = $relative
    }
  }
  return @($files)
}

function Is-ExcludedRelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$RelativePath
  )

  $normalized = Normalize-RelativePath -Path $RelativePath
  $excludedPrefixes = @(
    ".git/",
    "node_modules/",
    ".metrics/",
    "trellis-worktrees/",
    ".venv/",
    ".trellis/workspace/",
    ".trellis/tasks/"
  )

  foreach ($prefix in $excludedPrefixes) {
    if ($normalized.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }

  return $false
}

function Get-MinimalPresetFiles {
  param(
    [Parameter(Mandatory = $true)][string]$Root
  )

  $relativeFiles = @(
    "AGENTS.md",
    "CLAUDE.md",
    "workflow-policy.json",
    "sbk.config.json",
    ".claude/agents/dispatch.md",
    ".github/workflows/ci.yml",
    "scripts/sbk.ps1",
    "scripts/sbk-flow.ps1",
    "scripts/sbk-blueprint.ps1",
    "scripts/sbk-intake.ps1",
    "scripts/sbk-adapter.ps1",
    "scripts/sbk-semantic.ps1",
    "scripts/sbk-fleet.ps1",
    "scripts/sbk-install.ps1",
    "scripts/semantic-rename.ts",
    "scripts/semantic-index.py",
    "scripts/semantic-python.py",
    "scripts/common/sbk-runtime.ps1",
    "scripts/common/verify-telemetry.ps1",
    "scripts/verify-fast.ps1",
    "scripts/verify.ps1",
    "scripts/verify-ci.ps1",
    "scripts/verify-loop.ps1",
    "scripts/workflow-policy-gate.ps1",
    "scripts/workflow-indicator-gate.ps1",
    "scripts/workflow-doctor.ps1",
    "scripts/memory-context.ps1",
    "config/adapters/registry.json",
    "openspec/specs/codex-workflow-kernel/spec.md",
    "openspec/specs/workflow-security-policy/spec.md"
  )
  $relativeDirs = @(
    "config/blueprints",
    "config/release/channels"
  )

  $files = @()
  foreach ($relative in $relativeFiles) {
    $source = Resolve-SourceFile -Root $Root -RelativePath $relative
    if ($null -eq $source) {
      continue
    }
    $files += [PSCustomObject]@{
      source = $source
      relative = Normalize-RelativePath -Path $relative
    }
  }

  foreach ($relativeDir in $relativeDirs) {
    $files += Get-FilesFromRelativeDirectory -Root $Root -RelativeDirectory $relativeDir
  }

  $unique = @{}
  foreach ($item in $files) {
    $key = Normalize-RelativePath -Path ([string]$item.relative)
    if (Is-ExcludedRelativePath -RelativePath $key) {
      continue
    }
    if (-not $unique.ContainsKey($key)) {
      $unique[$key] = [PSCustomObject]@{
        source = [string]$item.source
        relative = $key
      }
    }
  }
  return @($unique.Values | Sort-Object -Property relative)
}

function Get-FullPresetFiles {
  param(
    [Parameter(Mandatory = $true)][string]$Root
  )

  $relativeDirs = @(
    "scripts",
    "config",
    "docs",
    "openspec/specs",
    ".trellis/spec",
    ".trellis/scripts",
    ".claude",
    ".codex",
    ".agents",
    ".github/workflows"
  )
  $relativeFiles = @(
    "AGENTS.md",
    "CLAUDE.md",
    "workflow-policy.json",
    "sbk.config.json"
  )

  $files = @()
  foreach ($relative in $relativeFiles) {
    $source = Resolve-SourceFile -Root $Root -RelativePath $relative
    if ($null -eq $source) {
      continue
    }
    $files += [PSCustomObject]@{
      source = $source
      relative = Normalize-RelativePath -Path $relative
    }
  }

  foreach ($relativeDir in $relativeDirs) {
    $files += Get-FilesFromRelativeDirectory -Root $Root -RelativeDirectory $relativeDir
  }

  $unique = @{}
  foreach ($item in $files) {
    $key = Normalize-RelativePath -Path ([string]$item.relative)
    if (Is-ExcludedRelativePath -RelativePath $key) {
      continue
    }
    if (-not $unique.ContainsKey($key)) {
      $unique[$key] = [PSCustomObject]@{
        source = [string]$item.source
        relative = $key
      }
    }
  }

  return @($unique.Values | Sort-Object -Property relative)
}

function Copy-FilesToTarget {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Files,
    [Parameter(Mandatory = $true)][string]$DestinationRoot,
    [Parameter(Mandatory = $true)][bool]$AllowOverwrite,
    [Parameter(Mandatory = $true)][hashtable]$Summary
  )

  foreach ($file in $Files) {
    $relative = Normalize-RelativePath -Path ([string]$file.relative)
    $source = [string]$file.source
    $destination = Join-Path $DestinationRoot ($relative -replace "/", "\")
    $destinationDir = Split-Path $destination -Parent
    if (-not (Test-Path $destinationDir)) {
      New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }

    if (Test-Path $destination) {
      if (-not $AllowOverwrite) {
        $Summary["skipped"]++
        continue
      }
      Copy-Item -Path $source -Destination $destination -Force
      $Summary["overwritten"]++
      continue
    }

    Copy-Item -Path $source -Destination $destination -Force
    $Summary["copied"]++
  }
}

function Update-PackageScripts {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot
  )

  $packagePath = Join-Path $RepoRoot "package.json"
  if (-not (Test-Path $packagePath -PathType Leaf)) {
    return [PSCustomObject]@{
      packageFound = $false
      scriptsAdded = 0
      scriptsExisting = 0
    }
  }

  $packageRaw = Get-Content -Path $packagePath -Encoding UTF8 -Raw
  $packageJson = $packageRaw | ConvertFrom-Json
  if ($null -eq $packageJson.scripts) {
    $packageJson | Add-Member -MemberType NoteProperty -Name scripts -Value ([pscustomobject]@{})
  }

  $desiredScripts = [ordered]@{
    "sbk" = "powershell -ExecutionPolicy Bypass -File ./scripts/sbk.ps1"
    "verify:fast" = "powershell -ExecutionPolicy Bypass -File ./scripts/verify-fast.ps1"
    "verify" = "powershell -ExecutionPolicy Bypass -File ./scripts/verify.ps1"
    "verify:ci" = "powershell -ExecutionPolicy Bypass -File ./scripts/verify-ci.ps1"
    "verify:loop" = "powershell -ExecutionPolicy Bypass -File ./scripts/verify-loop.ps1"
    "workflow:policy" = "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-policy-gate.ps1"
    "workflow:gate" = "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-indicator-gate.ps1"
    "workflow:doctor" = "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-doctor.ps1"
    "workflow:doctor:json" = "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-doctor-json.ps1"
    "workflow:docs-sync" = "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-docs-sync-gate.ps1"
    "workflow:skill-parity" = "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-skill-parity-gate.ps1"
    "memory:context" = "powershell -ExecutionPolicy Bypass -File ./scripts/memory-context.ps1"
    "metrics:collect" = "powershell -ExecutionPolicy Bypass -File ./scripts/collect-metrics.ps1"
  }
  $requiredScriptFiles = [ordered]@{
    "sbk" = "scripts/sbk.ps1"
    "verify:fast" = "scripts/verify-fast.ps1"
    "verify" = "scripts/verify.ps1"
    "verify:ci" = "scripts/verify-ci.ps1"
    "verify:loop" = "scripts/verify-loop.ps1"
    "workflow:policy" = "scripts/workflow-policy-gate.ps1"
    "workflow:gate" = "scripts/workflow-indicator-gate.ps1"
    "workflow:doctor" = "scripts/workflow-doctor.ps1"
    "workflow:doctor:json" = "scripts/workflow-doctor-json.ps1"
    "workflow:docs-sync" = "scripts/workflow-docs-sync-gate.ps1"
    "workflow:skill-parity" = "scripts/workflow-skill-parity-gate.ps1"
    "memory:context" = "scripts/memory-context.ps1"
    "metrics:collect" = "scripts/collect-metrics.ps1"
  }

  $scriptsAdded = 0
  $scriptsExisting = 0
  foreach ($scriptName in $desiredScripts.Keys) {
    $requiredRelative = [string]$requiredScriptFiles[$scriptName]
    $scriptPath = Join-Path $RepoRoot ($requiredRelative -replace "/", "\")
    if (-not (Test-Path $scriptPath -PathType Leaf)) {
      continue
    }

    $existingProperty = $packageJson.scripts.PSObject.Properties[$scriptName]
    if ($null -ne $existingProperty) {
      $scriptsExisting++
      continue
    }

    $packageJson.scripts | Add-Member -MemberType NoteProperty -Name $scriptName -Value $desiredScripts[$scriptName]
    $scriptsAdded++
  }

  if ($scriptsAdded -gt 0) {
    $updated = $packageJson | ConvertTo-Json -Depth 100
    Set-Content -Path $packagePath -Value $updated -Encoding UTF8
  }

  return [PSCustomObject]@{
    packageFound = $true
    scriptsAdded = $scriptsAdded
    scriptsExisting = $scriptsExisting
  }
}

$filesToCopy = if ($Preset -eq "minimal") {
  Get-MinimalPresetFiles -Root $sbkRoot
} else {
  Get-FullPresetFiles -Root $sbkRoot
}

$releaseManifest = Get-ReleaseManifest -Root $sbkRoot -SelectedChannel $Channel
$existingReleaseManifest = Read-TargetReleaseManifest -Root $targetRoot
$existingComparable = $null
if ($null -ne $existingReleaseManifest) {
  if ($null -ne $existingReleaseManifest.value.channel -and
    $null -ne $existingReleaseManifest.value.version) {
    $existingComparable = $existingReleaseManifest.value
  } else {
    $transition = $existingReleaseManifest.value.transition
    if ($null -ne $transition) {
      $existingComparable = [PSCustomObject]@{
        channel = [string]$transition.toChannel
        version = [string]$transition.toVersion
        publishedAt = [string]$existingReleaseManifest.value.generatedAt
      }
    }
  }
}
$compatibility = Test-ChannelCompatibility -CurrentManifest $releaseManifest.value -PreviousManifest $existingComparable
if (-not [bool]$compatibility.safe) {
  throw ("unsafe channel transition blocked: {0}" -f $compatibility.reason)
}

Copy-FilesToTarget -Files $filesToCopy -DestinationRoot $targetRoot -AllowOverwrite ([bool]$Overwrite) -Summary $stats

$packageSummary = [PSCustomObject]@{
  packageFound = $false
  scriptsAdded = 0
  scriptsExisting = 0
}
if (-not $SkipPackageScriptInjection) {
  $packageSummary = Update-PackageScripts -RepoRoot $targetRoot
}

Write-ReleaseAudit `
  -DestinationRoot $targetRoot `
  -CurrentManifest $releaseManifest.value `
  -PreviousManifest $existingComparable `
  -Compatibility $compatibility

Write-Host ("[sbk-install] preset={0} channel={1} target={2}" -f $Preset, $Channel, $targetRoot)
Write-Host ("[sbk-install] files_total={0} copied={1} overwritten={2} skipped={3}" -f $filesToCopy.Count, $stats.copied, $stats.overwritten, $stats.skipped)
Write-Host ("[sbk-install] channel_transition_safe={0} reason={1}" -f $compatibility.safe, $compatibility.reason)
if ($SkipPackageScriptInjection) {
  Write-Host "[sbk-install] package script injection skipped by flag"
} elseif ($packageSummary.packageFound) {
  Write-Host ("[sbk-install] package_json_scripts added={0} existing={1}" -f $packageSummary.scriptsAdded, $packageSummary.scriptsExisting)
} else {
  Write-Host "[sbk-install] package.json not found, script injection skipped"
}
