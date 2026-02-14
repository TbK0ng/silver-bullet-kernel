param(
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$CommandArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "common\\sbk-runtime.ps1")

function Show-Usage {
  Write-Host "sbk adapter <operation> [args]"
  Write-Host ""
  Write-Host "Operations:"
  Write-Host "  list"
  Write-Host "  validate --path <adapter-pack>"
  Write-Host "  register --path <adapter-pack>"
  Write-Host "  doctor [--target-repo-root <path>] [--adapter <name>] [--profile strict|balanced|lite]"
}

function Resolve-AdapterPackPath {
  param(
    [Parameter(Mandatory = $true)][string]$InputPath
  )

  $resolved = Resolve-SbkPath -BasePath $repoRoot -Path $InputPath
  if (-not (Test-Path $resolved)) {
    throw "adapter pack path does not exist: $resolved"
  }

  if (Test-Path $resolved -PathType Container) {
    $candidate = Join-Path $resolved "adapter.json"
    if (-not (Test-Path $candidate -PathType Leaf)) {
      throw "adapter pack directory must contain adapter.json: $resolved"
    }
    return (Resolve-Path $candidate).Path
  }

  return (Resolve-Path $resolved).Path
}

function Read-AdapterPack {
  param(
    [Parameter(Mandatory = $true)][string]$ManifestPath
  )

  $manifest = Read-SbkJsonFile -Path $ManifestPath
  if ($null -eq $manifest) {
    throw "adapter manifest is missing or invalid JSON: $ManifestPath"
  }
  return $manifest
}

function Test-StringArray {
  param($Value)
  if ($null -eq $Value) {
    return $false
  }
  $items = @($Value | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  return $items.Count -gt 0
}

function Validate-AdapterPack {
  param(
    [Parameter(Mandatory = $true)]$Pack,
    [Parameter(Mandatory = $true)][string]$ManifestPath
  )

  $errors = @()
  $metadata = Get-SbkPropertyValue -Object $Pack -Name "metadata"
  $name = [string](Get-SbkPropertyValue -Object $metadata -Name "name")
  $version = [string](Get-SbkPropertyValue -Object $metadata -Name "version")
  if ([string]::IsNullOrWhiteSpace($name)) {
    $errors += "metadata.name is required"
  }
  if ([string]::IsNullOrWhiteSpace($version)) {
    $errors += "metadata.version is required"
  }

  $detect = Get-SbkPropertyValue -Object $Pack -Name "detect"
  if (-not (Test-StringArray -Value (Get-SbkPropertyValue -Object $detect -Name "anyOfFiles"))) {
    $errors += "detect.anyOfFiles must be a non-empty string array"
  }

  $implementation = Get-SbkPropertyValue -Object $Pack -Name "implementation"
  $hasImplementationPrefixes = Test-StringArray -Value (Get-SbkPropertyValue -Object $implementation -Name "pathPrefixes")
  $hasImplementationFiles = Test-StringArray -Value (Get-SbkPropertyValue -Object $implementation -Name "pathFiles")
  if (-not ($hasImplementationPrefixes -or $hasImplementationFiles)) {
    $errors += "implementation.pathPrefixes or implementation.pathFiles must be provided"
  }

  $verify = Get-SbkPropertyValue -Object $Pack -Name "verify"
  foreach ($mode in @("fast", "full", "ci")) {
    $modeValue = Get-SbkPropertyValue -Object $verify -Name $mode
    if ($null -eq $modeValue) {
      $errors += "verify.$mode must be present (can be empty array)"
    }
  }

  $semantic = Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $Pack -Name "capabilities") -Name "semantic"
  $renameCapability = Get-SbkPropertyValue -Object $semantic -Name "rename"
  $renameSupported = Get-SbkPropertyValue -Object $renameCapability -Name "supported"
  if ($null -eq $renameSupported) {
    $errors += "capabilities.semantic.rename.supported must be present"
  }

  return [ordered]@{
    name = $name
    version = $version
    path = $ManifestPath
    valid = ($errors.Count -eq 0)
    errors = $errors
  }
}

function New-NormalizedAdapterManifest {
  param(
    [Parameter(Mandatory = $true)]$Pack,
    [Parameter(Mandatory = $true)]$Validation,
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][bool]$Validated
  )

  $metadata = Get-SbkPropertyValue -Object $Pack -Name "metadata"
  $priorityRaw = Get-SbkPropertyValue -Object $metadata -Name "priority"
  $priority = 40
  if ($null -ne $priorityRaw) {
    $priority = [int]$priorityRaw
  }

  return [ordered]@{
    name = [string]$Validation.name
    priority = $priority
    detect = Get-SbkPropertyValue -Object $Pack -Name "detect"
    implementation = Get-SbkPropertyValue -Object $Pack -Name "implementation"
    verify = Get-SbkPropertyValue -Object $Pack -Name "verify"
    capabilities = Get-SbkPropertyValue -Object $Pack -Name "capabilities"
    policyScope = Get-SbkPropertyValue -Object $Pack -Name "policyScope"
    sdk = [ordered]@{
      source = "plugin"
      validated = $Validated
      validationStatus = if ($Validated) { "validated" } else { "unvalidated" }
      validatedAt = if ($Validated) { [DateTimeOffset]::UtcNow.ToString("o") } else { "" }
      manifestPath = $ManifestPath
      metadata = [ordered]@{
        version = [string]$Validation.version
        author = [string](Get-SbkPropertyValue -Object $metadata -Name "author")
      }
    }
  }
}

function Write-AdapterRegistryEntry {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$Version
  )

  $registryPath = Join-Path $repoRoot "config\\adapters\\registry.json"
  $registry = Read-SbkJsonFile -Path $registryPath
  if ($null -eq $registry) {
    $registry = [PSCustomObject]@{
      version = 1
      generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
      adapters = @()
    }
  }

  $entries = @($registry.adapters | Where-Object { [string]$_.name -ne $Name })
  $entries += [PSCustomObject]@{
    name = $Name
    source = "plugin"
    validated = $true
    version = $Version
    registeredAt = [DateTimeOffset]::UtcNow.ToString("o")
    manifestPath = $ManifestPath
  }

  $registry.adapters = $entries | Sort-Object { [string]$_.name }
  $registry.generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
  Set-Content -Path $registryPath -Value ($registry | ConvertTo-Json -Depth 20) -Encoding UTF8
}

function Write-ValidationReport {
  param(
    [Parameter(Mandatory = $true)]$Validation
  )

  $metricsDir = Join-Path $repoRoot ".metrics"
  if (-not (Test-Path $metricsDir)) {
    New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
  }
  $safeName = if ([string]::IsNullOrWhiteSpace([string]$Validation.name)) { "unknown" } else { [string]$Validation.name }
  $path = Join-Path $metricsDir ("adapter-validate-{0}.json" -f $safeName)
  Set-Content -Path $path -Value ($Validation | ConvertTo-Json -Depth 20) -Encoding UTF8
}

function Invoke-AdapterDoctor {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot,
    [Parameter(Mandatory = $true)][string]$AdapterOverride,
    [Parameter(Mandatory = $true)][string]$ProfileOverride
  )

  $runtime = Get-SbkRuntimeContext `
    -SbkRoot $repoRoot `
    -TargetRepoRoot $TargetRepoRoot `
    -AdapterOverride $AdapterOverride `
    -ProfileOverride $ProfileOverride
  $adapters = @(Get-SbkAdapterManifests -AdaptersRoot $runtime.adaptersRoot)
  $active = @($adapters | Where-Object { [string](Get-SbkPropertyValue -Object $_ -Name "name") -eq $runtime.adapter } | Select-Object -First 1)
  if ($active.Count -eq 0) {
    throw "active adapter '$($runtime.adapter)' manifest not found under $($runtime.adaptersRoot)"
  }

  $adapter = $active[0]
  $sdk = Get-SbkPropertyValue -Object $adapter -Name "sdk"
  $validated = $true
  if ($null -ne $sdk) {
    $candidate = Get-SbkPropertyValue -Object $sdk -Name "validated"
    if ($null -ne $candidate) {
      $validated = [bool]$candidate
    }
  }

  $missing = @()
  if (-not (Test-StringArray -Value (Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $adapter -Name "implementation") -Name "pathPrefixes")) -and
    -not (Test-StringArray -Value (Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $adapter -Name "implementation") -Name "pathFiles"))) {
    $missing += "implementation paths"
  }
  foreach ($mode in @("fast", "full", "ci")) {
    $value = Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $adapter -Name "verify") -Name $mode
    if ($null -eq $value) {
      $missing += "verify.$mode"
    }
  }
  $renameCapability = Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $adapter -Name "capabilities") -Name "semantic") -Name "rename"
  if ($null -eq $renameCapability) {
    $missing += "capabilities.semantic.rename"
  }

  $report = [ordered]@{
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    targetRepoRoot = $TargetRepoRoot
    profile = $runtime.profile
    activeAdapter = $runtime.adapter
    validationStatus = if ($validated) { "validated" } else { "unvalidated" }
    missingCapabilities = $missing
    remediation = if ($missing.Count -eq 0 -and $validated) {
      @("none")
    } else {
      @(
        "Run `sbk adapter validate --path <adapter-pack>` and ensure schema completeness.",
        "Run `sbk adapter register --path <adapter-pack>` after successful validation.",
        "Populate verify matrix and semantic capability declarations."
      )
    }
    passed = ($missing.Count -eq 0 -and $validated)
  }

  $metricsDir = Join-Path $repoRoot ".metrics"
  if (-not (Test-Path $metricsDir)) {
    New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
  }
  Set-Content -Path (Join-Path $metricsDir "adapter-doctor.json") -Value ($report | ConvertTo-Json -Depth 20) -Encoding UTF8
  Set-Content -Path (Join-Path $metricsDir "adapter-doctor.md") -Value @(
    "# Adapter Doctor",
    "",
    "- generated_at_utc: $([DateTimeOffset]::UtcNow.ToString("u"))",
    "- target_repo_root: $TargetRepoRoot",
    "- profile: $($runtime.profile)",
    "- active_adapter: $($runtime.adapter)",
    "- validation_status: $(if ($validated) { "validated" } else { "unvalidated" })",
    "- missing_capabilities: $(if ($missing.Count -eq 0) { "none" } else { $missing -join ", " })"
  ) -Encoding UTF8

  Write-Host ("[adapter] doctor adapter={0} validated={1} missing={2}" -f $runtime.adapter, $validated, $missing.Count)
  if (-not [bool]$report.passed) {
    throw "adapter doctor failed"
  }
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

switch ($operation.ToLowerInvariant()) {
  "list" {
    $registryPath = Join-Path $repoRoot "config\\adapters\\registry.json"
    $registry = Read-SbkJsonFile -Path $registryPath
    if ($null -eq $registry) {
      throw "adapter registry missing: $registryPath"
    }
    $entries = @($registry.adapters | Sort-Object { [string]$_.name })
    Write-Host "registered adapters"
    foreach ($entry in $entries) {
      Write-Host ("- {0} source={1} validated={2} manifest={3}" -f $entry.name, $entry.source, $entry.validated, $entry.manifestPath)
    }
    break
  }
  "validate" {
    $inputPath = ""
    for ($i = 0; $i -lt $rest.Count; $i++) {
      if ([string]$rest[$i] -eq "--path" -and ($i + 1) -lt $rest.Count) {
        $inputPath = [string]$rest[$i + 1]
        $i++
      }
    }
    if ([string]::IsNullOrWhiteSpace($inputPath)) {
      throw "adapter validate requires --path <adapter-pack>"
    }

    $manifestPath = Resolve-AdapterPackPath -InputPath $inputPath
    $pack = Read-AdapterPack -ManifestPath $manifestPath
    $validation = Validate-AdapterPack -Pack $pack -ManifestPath $manifestPath
    Write-ValidationReport -Validation $validation

    if (-not [bool]$validation.valid) {
      Write-Host ("[adapter] validate failed path={0}" -f $manifestPath)
      foreach ($errorMessage in @($validation.errors)) {
        Write-Host ("  - {0}" -f $errorMessage)
      }
      throw "adapter validation failed"
    }

    Write-Host ("[adapter] validate passed name={0} version={1}" -f $validation.name, $validation.version)
    break
  }
  "register" {
    $inputPath = ""
    for ($i = 0; $i -lt $rest.Count; $i++) {
      if ([string]$rest[$i] -eq "--path" -and ($i + 1) -lt $rest.Count) {
        $inputPath = [string]$rest[$i + 1]
        $i++
      }
    }
    if ([string]::IsNullOrWhiteSpace($inputPath)) {
      throw "adapter register requires --path <adapter-pack>"
    }

    $manifestPath = Resolve-AdapterPackPath -InputPath $inputPath
    $pack = Read-AdapterPack -ManifestPath $manifestPath
    $validation = Validate-AdapterPack -Pack $pack -ManifestPath $manifestPath
    Write-ValidationReport -Validation $validation
    if (-not [bool]$validation.valid) {
      throw "adapter register blocked: validate failed"
    }

    $normalized = New-NormalizedAdapterManifest `
      -Pack $pack `
      -Validation $validation `
      -ManifestPath $manifestPath `
      -Validated $true
    $pluginsDir = Join-Path $repoRoot "config\\adapters\\plugins"
    if (-not (Test-Path $pluginsDir)) {
      New-Item -ItemType Directory -Path $pluginsDir -Force | Out-Null
    }
    $outputPath = Join-Path $pluginsDir ("{0}.json" -f $validation.name)
    Set-Content -Path $outputPath -Value ($normalized | ConvertTo-Json -Depth 20) -Encoding UTF8

    $relativeManifest = ("config/adapters/plugins/{0}.json" -f $validation.name)
    Write-AdapterRegistryEntry -Name $validation.name -ManifestPath $relativeManifest -Version $validation.version
    Write-Host ("[adapter] register name={0} manifest={1}" -f $validation.name, $relativeManifest)
    break
  }
  "doctor" {
    $targetRepoRoot = "."
    $adapter = ""
    $profile = ""
    for ($i = 0; $i -lt $rest.Count; $i++) {
      $token = [string]$rest[$i]
      if ($token -eq "--target-repo-root" -and ($i + 1) -lt $rest.Count) {
        $targetRepoRoot = [string]$rest[$i + 1]
        $i++
        continue
      }
      if ($token -eq "--adapter" -and ($i + 1) -lt $rest.Count) {
        $adapter = [string]$rest[$i + 1]
        $i++
        continue
      }
      if ($token -eq "--profile" -and ($i + 1) -lt $rest.Count) {
        $profile = [string]$rest[$i + 1]
        $i++
        continue
      }
    }

    $resolvedTarget = Resolve-SbkPath -BasePath $repoRoot -Path $targetRepoRoot
    Invoke-AdapterDoctor -TargetRepoRoot $resolvedTarget -AdapterOverride $adapter -ProfileOverride $profile
    break
  }
  default {
    throw "unknown adapter operation: $operation"
  }
}
