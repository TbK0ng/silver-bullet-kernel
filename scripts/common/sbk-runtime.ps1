Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-SbkJsonFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path
  )

  if (-not (Test-Path $Path)) {
    return $null
  }

  $raw = Get-Content -Path $Path -Encoding UTF8 -Raw
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return $null
  }

  return ($raw | ConvertFrom-Json)
}

function Resolve-SbkPath {
  param(
    [Parameter(Mandatory = $true)][string]$BasePath,
    [Parameter(Mandatory = $true)][string]$Path
  )

  if ([System.IO.Path]::IsPathRooted($Path)) {
    $resolvedRooted = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($null -ne $resolvedRooted) {
      return $resolvedRooted.Path
    }
    return $Path
  }

  $resolved = Join-Path $BasePath ($Path -replace "/", "\\")
  $resolvedRelative = Resolve-Path -LiteralPath $resolved -ErrorAction SilentlyContinue
  if ($null -ne $resolvedRelative) {
    return $resolvedRelative.Path
  }
  return $resolved
}

function Get-SbkPropertyValue {
  param(
    [Parameter(Mandatory = $false)]$Object,
    [Parameter(Mandatory = $true)][string]$Name
  )

  if ($null -eq $Object) {
    return $null
  }

  $property = $Object.PSObject.Properties | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
  if ($null -eq $property) {
    return $null
  }

  return $property.Value
}

function Get-SbkAdapterManifests {
  param(
    [Parameter(Mandatory = $true)][string]$AdaptersRoot
  )

  if (-not (Test-Path $AdaptersRoot)) {
    return @()
  }

  $items = @(Get-ChildItem -Path $AdaptersRoot -File -Filter "*.json" | Sort-Object -Property Name)
  $adapters = @()
  foreach ($item in $items) {
    $parsed = Read-SbkJsonFile -Path $item.FullName
    if ($null -eq $parsed) {
      continue
    }

    $parsedName = [string](Get-SbkPropertyValue -Object $parsed -Name "name")
    if ([string]::IsNullOrWhiteSpace($parsedName)) {
      $parsed | Add-Member -NotePropertyName "name" -NotePropertyValue $item.BaseName
    }

    $adapters += $parsed
  }

  return @($adapters)
}

function Resolve-SbkAdapterName {
  param(
    [Parameter(Mandatory = $true)][string]$RequestedAdapter,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Adapters,
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot
  )

  if ($Adapters.Count -eq 0) {
    return ""
  }

  $availableNames = @($Adapters | ForEach-Object { [string](Get-SbkPropertyValue -Object $_ -Name "name") })

  if (-not [string]::IsNullOrWhiteSpace($RequestedAdapter) -and -not $RequestedAdapter.Equals("auto", [System.StringComparison]::OrdinalIgnoreCase)) {
    if ($availableNames -contains $RequestedAdapter) {
      return $RequestedAdapter
    }
    return $availableNames[0]
  }

  $matches = @()
  foreach ($adapter in $Adapters) {
    $markerFiles = @()
    $detect = Get-SbkPropertyValue -Object $adapter -Name "detect"
    $anyOfFiles = Get-SbkPropertyValue -Object $detect -Name "anyOfFiles"
    if ($null -ne $anyOfFiles) {
      $markerFiles = @($anyOfFiles | ForEach-Object { [string]$_ })
    }

    if ($markerFiles.Count -eq 0) {
      continue
    }

    $isMatch = $false
    foreach ($marker in $markerFiles) {
      $candidate = Join-Path $TargetRepoRoot ($marker -replace "/", "\\")
      if (Test-Path $candidate) {
        $isMatch = $true
        break
      }
    }

    if ($isMatch) {
      $priority = 0
      $adapterPriority = Get-SbkPropertyValue -Object $adapter -Name "priority"
      if ($null -ne $adapterPriority) {
        $priority = [int]$adapterPriority
      }
      $matches += [PSCustomObject]@{
        name = [string](Get-SbkPropertyValue -Object $adapter -Name "name")
        priority = $priority
      }
    }
  }

  if ($matches.Count -gt 0) {
    $selected = $matches | Sort-Object -Property @{ Expression = "priority"; Descending = $true }, @{ Expression = "name"; Descending = $false } | Select-Object -First 1
    return [string]$selected.name
  }

  if ($availableNames -contains "node-ts") {
    return "node-ts"
  }

  return $availableNames[0]
}

function Get-SbkRuntimeContext {
  param(
    [Parameter(Mandatory = $true)][string]$SbkRoot,
    [string]$TargetConfigPath = "",
    [string]$TargetRepoRoot = "",
    [string]$AdapterOverride = "",
    [string]$ProfileOverride = ""
  )

  $runtimeConfigPath = if ([string]::IsNullOrWhiteSpace($TargetConfigPath)) {
    Join-Path $SbkRoot "sbk.config.json"
  } else {
    if ([System.IO.Path]::IsPathRooted($TargetConfigPath)) {
      $TargetConfigPath
    } else {
      Join-Path $SbkRoot ($TargetConfigPath -replace "/", "\\")
    }
  }

  $runtimeConfig = Read-SbkJsonFile -Path $runtimeConfigPath
  if ($null -eq $runtimeConfig) {
    $runtimeConfig = [PSCustomObject]@{
      adapter = "node-ts"
      profile = "strict"
      targetRepoRoot = "."
      adaptersDir = "config/adapters"
    }
  }

  $resolvedTargetRepoRaw = if (-not [string]::IsNullOrWhiteSpace($TargetRepoRoot)) {
    $TargetRepoRoot
  } elseif (-not [string]::IsNullOrWhiteSpace($env:SBK_TARGET_REPO_ROOT)) {
    $env:SBK_TARGET_REPO_ROOT
  } else {
    $configTargetRoot = [string](Get-SbkPropertyValue -Object $runtimeConfig -Name "targetRepoRoot")
    if (-not [string]::IsNullOrWhiteSpace($configTargetRoot)) {
      $configTargetRoot
    } else {
      "."
    }
  }

  $resolvedTargetRepoRoot = Resolve-SbkPath -BasePath $SbkRoot -Path $resolvedTargetRepoRaw

  $configAdaptersDir = [string](Get-SbkPropertyValue -Object $runtimeConfig -Name "adaptersDir")
  $adaptersDirRaw = if (-not [string]::IsNullOrWhiteSpace($configAdaptersDir)) {
    $configAdaptersDir
  } else {
    "config/adapters"
  }
  $adaptersRoot = Resolve-SbkPath -BasePath $SbkRoot -Path $adaptersDirRaw
  $adapters = @(Get-SbkAdapterManifests -AdaptersRoot $adaptersRoot)

  $requestedAdapter = if (-not [string]::IsNullOrWhiteSpace($AdapterOverride)) {
    $AdapterOverride
  } elseif (-not [string]::IsNullOrWhiteSpace($env:SBK_ADAPTER)) {
    $env:SBK_ADAPTER
  } else {
    $configAdapter = [string](Get-SbkPropertyValue -Object $runtimeConfig -Name "adapter")
    if (-not [string]::IsNullOrWhiteSpace($configAdapter)) {
      $configAdapter
    } else {
      "node-ts"
    }
  }

  $resolvedAdapterName = Resolve-SbkAdapterName -RequestedAdapter $requestedAdapter -Adapters $adapters -TargetRepoRoot $resolvedTargetRepoRoot
  $resolvedAdapter = $null
  if (-not [string]::IsNullOrWhiteSpace($resolvedAdapterName)) {
    $resolvedAdapter = $adapters | Where-Object { [string](Get-SbkPropertyValue -Object $_ -Name "name") -eq $resolvedAdapterName } | Select-Object -First 1
  }

  if ($null -eq $resolvedAdapter) {
    $resolvedAdapter = [PSCustomObject]@{
      name = "node-ts"
      implementation = [PSCustomObject]@{ pathPrefixes = @(); pathFiles = @() }
      verify = [PSCustomObject]@{ fast = @(); full = @(); ci = @() }
    }
  }

  $profileName = if (-not [string]::IsNullOrWhiteSpace($ProfileOverride)) {
    $ProfileOverride
  } elseif (-not [string]::IsNullOrWhiteSpace($env:SBK_PROFILE)) {
    $env:SBK_PROFILE
  } else {
    $configProfile = [string](Get-SbkPropertyValue -Object $runtimeConfig -Name "profile")
    if (-not [string]::IsNullOrWhiteSpace($configProfile)) {
      $configProfile
    } else {
      "strict"
    }
  }

  $workflowGateOverrides = @{}
  $profilesConfig = Get-SbkPropertyValue -Object $runtimeConfig -Name "profiles"
  if ($null -ne $profilesConfig) {
    $profileProperty = $profilesConfig.PSObject.Properties | Where-Object { $_.Name -eq $profileName } | Select-Object -First 1
    if ($null -ne $profileProperty) {
      $workflowOverrides = Get-SbkPropertyValue -Object $profileProperty.Value -Name "workflowGateOverrides"
      if ($null -ne $workflowOverrides) {
        foreach ($item in $workflowOverrides.PSObject.Properties) {
          $workflowGateOverrides[$item.Name] = $item.Value
        }
      }
    }
  }

  $docsSync = [PSCustomObject]@{
    enabled = $false
    triggerPathPrefixes = @()
    triggerPathFiles = @()
    requiredDocs = @()
  }
  $docsSyncConfig = Get-SbkPropertyValue -Object $runtimeConfig -Name "docsSync"
  if ($null -ne $docsSyncConfig) {
    $docsSyncEnabled = Get-SbkPropertyValue -Object $docsSyncConfig -Name "enabled"
    $docsSyncPrefixes = Get-SbkPropertyValue -Object $docsSyncConfig -Name "triggerPathPrefixes"
    $docsSyncFiles = Get-SbkPropertyValue -Object $docsSyncConfig -Name "triggerPathFiles"
    $docsSyncRequired = Get-SbkPropertyValue -Object $docsSyncConfig -Name "requiredDocs"

    $docsSync = [PSCustomObject]@{
      enabled = [bool]$docsSyncEnabled
      triggerPathPrefixes = @($docsSyncPrefixes | ForEach-Object { [string]$_ })
      triggerPathFiles = @($docsSyncFiles | ForEach-Object { [string]$_ })
      requiredDocs = @($docsSyncRequired | ForEach-Object { [string]$_ })
    }
  }

  $implementationConfig = Get-SbkPropertyValue -Object $resolvedAdapter -Name "implementation"
  $verifyConfig = Get-SbkPropertyValue -Object $resolvedAdapter -Name "verify"

  $implementationPrefixes = @()
  $implementationFiles = @()
  $verifyFast = @()
  $verifyFull = @()
  $verifyCi = @()

  if ($null -ne $implementationConfig) {
    $implementationPrefixes = @((Get-SbkPropertyValue -Object $implementationConfig -Name "pathPrefixes") | ForEach-Object { [string]$_ })
    $implementationFiles = @((Get-SbkPropertyValue -Object $implementationConfig -Name "pathFiles") | ForEach-Object { [string]$_ })
  }
  if ($null -ne $verifyConfig) {
    $verifyFast = @((Get-SbkPropertyValue -Object $verifyConfig -Name "fast") | ForEach-Object { [string]$_ })
    $verifyFull = @((Get-SbkPropertyValue -Object $verifyConfig -Name "full") | ForEach-Object { [string]$_ })
    $verifyCi = @((Get-SbkPropertyValue -Object $verifyConfig -Name "ci") | ForEach-Object { [string]$_ })
  }

  return [PSCustomObject]@{
    sbkRoot = $SbkRoot
    targetRepoRoot = $resolvedTargetRepoRoot
    runtimeConfigPath = $runtimeConfigPath
    adaptersRoot = $adaptersRoot
    adapter = [string](Get-SbkPropertyValue -Object $resolvedAdapter -Name "name")
    requestedAdapter = $requestedAdapter
    profile = $profileName
    workflowGateOverrides = $workflowGateOverrides
    implementationPathPrefixes = @($implementationPrefixes)
    implementationPathFiles = @($implementationFiles)
    verify = [PSCustomObject]@{
      fast = @($verifyFast)
      full = @($verifyFull)
      ci = @($verifyCi)
    }
    docsSync = $docsSync
  }
}

function Get-SbkVerifyCommands {
  param(
    [Parameter(Mandatory = $true)]$Runtime,
    [Parameter(Mandatory = $true)][ValidateSet("fast", "full", "ci")][string]$Mode
  )

  $commands = @()
  switch ($Mode) {
    "fast" { $commands = @($Runtime.verify.fast) }
    "full" { $commands = @($Runtime.verify.full) }
    "ci" { $commands = @($Runtime.verify.ci) }
  }

  return @($commands | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
}

function Get-SbkPlatformCapabilities {
  param(
    [Parameter(Mandatory = $true)][string]$SbkRoot,
    [string]$TargetRepoRoot = "",
    [string]$PlatformOverride = ""
  )

  $capabilitiesPath = Join-Path $SbkRoot "config\\platform-capabilities.json"
  $capabilitiesConfig = Read-SbkJsonFile -Path $capabilitiesPath

  if ($null -eq $capabilitiesConfig) {
    $capabilitiesConfig = [PSCustomObject]@{
      version = 1
      defaultPlatform = "claude"
      platforms = @(
        [PSCustomObject]@{
          name = "claude"
          displayName = "Claude Code"
          supportsCliAgents = $true
          supportsSessionIdOnCreate = $true
          supportsResume = $true
          supportsSkipPermissions = $true
          manualMode = $false
          resumeHint = "claude --resume <session-id>"
        },
        [PSCustomObject]@{
          name = "codex"
          displayName = "Codex"
          supportsCliAgents = $false
          supportsSessionIdOnCreate = $false
          supportsResume = $false
          supportsSkipPermissions = $false
          manualMode = $true
          resumeHint = "Open worktree in Codex and continue from .trellis/.current-task"
        }
      )
      detection = [PSCustomObject]@{
        directories = @(
          [PSCustomObject]@{ name = "claude"; path = ".claude" },
          [PSCustomObject]@{ name = "codex"; path = ".agents/skills" }
        )
      }
    }
  }

  $platforms = @(Get-SbkPropertyValue -Object $capabilitiesConfig -Name "platforms")
  $defaultPlatformRaw = [string](Get-SbkPropertyValue -Object $capabilitiesConfig -Name "defaultPlatform")
  $defaultPlatform = if ([string]::IsNullOrWhiteSpace($defaultPlatformRaw)) { "claude" } else { $defaultPlatformRaw.ToLowerInvariant() }
  $selectedPlatformName = ""

  if (-not [string]::IsNullOrWhiteSpace($PlatformOverride)) {
    $selectedPlatformName = $PlatformOverride
  } elseif (-not [string]::IsNullOrWhiteSpace($env:SBK_PLATFORM)) {
    $selectedPlatformName = $env:SBK_PLATFORM
  } elseif (-not [string]::IsNullOrWhiteSpace($env:TRELLIS_PLATFORM)) {
    $selectedPlatformName = $env:TRELLIS_PLATFORM
  }

  $targetRoot = if (-not [string]::IsNullOrWhiteSpace($TargetRepoRoot)) {
    Resolve-SbkPath -BasePath $SbkRoot -Path $TargetRepoRoot
  } else {
    $SbkRoot
  }

  if ([string]::IsNullOrWhiteSpace($selectedPlatformName)) {
    $detection = Get-SbkPropertyValue -Object $capabilitiesConfig -Name "detection"
    $detectionDirs = @(Get-SbkPropertyValue -Object $detection -Name "directories")
    foreach ($entry in $detectionDirs) {
      $entryName = [string](Get-SbkPropertyValue -Object $entry -Name "name")
      $entryPath = [string](Get-SbkPropertyValue -Object $entry -Name "path")
      if ([string]::IsNullOrWhiteSpace($entryName) -or [string]::IsNullOrWhiteSpace($entryPath)) {
        continue
      }

      $candidatePath = Join-Path $targetRoot ($entryPath -replace "/", "\\")
      if (Test-Path $candidatePath) {
        $selectedPlatformName = $entryName
        break
      }
    }
  }

  if ([string]::IsNullOrWhiteSpace($selectedPlatformName)) {
    $selectedPlatformName = $defaultPlatform
  }
  $selectedPlatformName = $selectedPlatformName.ToLowerInvariant()

  $selectedPlatform = $platforms | Where-Object { [string](Get-SbkPropertyValue -Object $_ -Name "name") -eq $selectedPlatformName } | Select-Object -First 1
  if ($null -eq $selectedPlatform) {
    $selectedPlatform = $platforms | Where-Object { [string](Get-SbkPropertyValue -Object $_ -Name "name") -eq $defaultPlatform } | Select-Object -First 1
  }
  if ($null -eq $selectedPlatform) {
    $selectedPlatform = $platforms | Select-Object -First 1
  }

  $resolvedPlatformName = [string](Get-SbkPropertyValue -Object $selectedPlatform -Name "name")
  if ([string]::IsNullOrWhiteSpace($resolvedPlatformName)) {
    $resolvedPlatformName = $defaultPlatform
  }

  return [PSCustomObject]@{
    path = $capabilitiesPath
    version = [int](Get-SbkPropertyValue -Object $capabilitiesConfig -Name "version")
    defaultPlatform = $defaultPlatform
    selectedPlatformName = $resolvedPlatformName
    selectedPlatform = $selectedPlatform
    platforms = @($platforms)
    targetRepoRoot = $targetRoot
  }
}
