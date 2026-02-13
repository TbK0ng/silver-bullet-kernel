param(
  [string]$Change = "",
  [switch]$Apply,
  [switch]$NoValidate,
  [switch]$UnsafeOverwrite
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

function Invoke-OpenSpecJson {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Args
  )

  Push-Location $repoRoot
  try {
    $raw = & openspec @Args
    if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
      throw "openspec command failed: openspec $($Args -join ' ')"
    }

    $text = [string]::Join([Environment]::NewLine, @($raw))
    if ([string]::IsNullOrWhiteSpace($text)) {
      throw "openspec returned empty JSON response."
    }
    return ($text | ConvertFrom-Json)
  } finally {
    Pop-Location
  }
}

function Resolve-ChangeName {
  param([string]$RequestedChange)

  if (-not [string]::IsNullOrWhiteSpace($RequestedChange)) {
    return $RequestedChange
  }

  $listResult = Invoke-OpenSpecJson -Args @("list", "--json")
  $activeChanges = @($listResult.changes)

  if ($activeChanges.Count -eq 1) {
    return [string]$activeChanges[0].name
  }

  if ($activeChanges.Count -eq 0) {
    throw "no active OpenSpec changes found."
  }

  $names = @($activeChanges | ForEach-Object { [string]$_.name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  throw ("multiple active changes found; pass --change <id>. available: " + ($names -join ", "))
}

function Get-RelativeRepoPath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $fullRoot = [System.IO.Path]::GetFullPath($Root)
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  if ($fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $fullPath.Substring($fullRoot.Length).TrimStart('\', '/') -replace "\\", "/"
  }
  return $fullPath -replace "\\", "/"
}

function Normalize-MarkdownText {
  param([AllowNull()][string]$Text)

  if ($null -eq $Text) {
    return ""
  }

  return ([string]$Text).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Get-RequirementBlocks {
  param([AllowNull()][string]$Text)

  $normalized = Normalize-MarkdownText -Text $Text
  if ([string]::IsNullOrWhiteSpace($normalized)) {
    return @()
  }

  $matches = [regex]::Matches(
    $normalized,
    '(?ms)^###\s+Requirement:\s*(?<name>[^\n]+)(?:\n(?<body>.*?))?(?=^###\s+Requirement:|\z)'
  )

  $result = @()
  foreach ($match in $matches) {
    $name = [string]$match.Groups["name"].Value.Trim()
    if ([string]::IsNullOrWhiteSpace($name)) {
      continue
    }
    $raw = [string]$match.Value.Trim("`n")
    $result += [PSCustomObject]@{
      name = $name
      raw = $raw
    }
  }

  return @($result)
}

function Parse-RequirementBlock {
  param([Parameter(Mandatory = $true)][string]$RequirementBlock)

  $normalized = Normalize-MarkdownText -Text $RequirementBlock
  $match = [regex]::Match(
    $normalized,
    '(?ms)^###\s+Requirement:\s*(?<name>[^\n]+)(?:\n(?<body>.*))?$'
  )
  if (-not $match.Success) {
    throw "invalid requirement block; expected '### Requirement:' heading."
  }

  $name = [string]$match.Groups["name"].Value.Trim()
  $body = ""
  if ($match.Groups["body"].Success) {
    $body = [string]$match.Groups["body"].Value
  }

  $scenarioMatches = [regex]::Matches(
    $body,
    '(?ms)^####\s+Scenario:\s*(?<name>[^\n]+)\n(?<body>.*?)(?=^####\s+Scenario:|\z)'
  )

  $intro = ""
  if ($scenarioMatches.Count -gt 0) {
    $intro = $body.Substring(0, $scenarioMatches[0].Index).Trim("`n")
  } else {
    $intro = $body.Trim("`n")
  }

  $scenarios = @()
  foreach ($scenarioMatch in $scenarioMatches) {
    $scenarioName = [string]$scenarioMatch.Groups["name"].Value.Trim()
    if ([string]::IsNullOrWhiteSpace($scenarioName)) {
      continue
    }
    $scenarios += [PSCustomObject]@{
      name = $scenarioName
      raw = [string]$scenarioMatch.Value.Trim("`n")
    }
  }

  return [PSCustomObject]@{
    name = $name
    intro = $intro
    scenarios = @($scenarios)
  }
}

function Build-RequirementBlock {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [AllowNull()][string]$Intro,
    [AllowEmptyCollection()][object[]]$Scenarios = @()
  )

  if ([string]::IsNullOrWhiteSpace($Name)) {
    throw "requirement name cannot be empty."
  }

  $parts = @("### Requirement: $Name")
  $introText = Normalize-MarkdownText -Text $Intro
  if (-not [string]::IsNullOrWhiteSpace($introText.Trim())) {
    $parts += ""
    $parts += $introText.Trim("`n")
  }

  foreach ($scenario in $Scenarios) {
    $scenarioRaw = Normalize-MarkdownText -Text ([string]$scenario.raw)
    if ([string]::IsNullOrWhiteSpace($scenarioRaw.Trim())) {
      continue
    }
    $parts += ""
    $parts += $scenarioRaw.Trim("`n")
  }

  return ($parts -join "`n").Trim("`n")
}

function Merge-RequirementBlocks {
  param(
    [Parameter(Mandatory = $true)][string]$CanonicalBlock,
    [Parameter(Mandatory = $true)][string]$DeltaBlock
  )

  $canonical = Parse-RequirementBlock -RequirementBlock $CanonicalBlock
  $delta = Parse-RequirementBlock -RequirementBlock $DeltaBlock

  if (-not [string]::Equals($canonical.name, $delta.name, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw ("cannot merge mismatched requirement blocks: '{0}' vs '{1}'." -f $canonical.name, $delta.name)
  }

  $mergedIntro = if (-not [string]::IsNullOrWhiteSpace(($delta.intro).Trim())) {
    $delta.intro
  } else {
    $canonical.intro
  }

  $mergedScenarios = @()
  foreach ($scenario in $canonical.scenarios) {
    $mergedScenarios += [PSCustomObject]@{
      name = [string]$scenario.name
      raw = [string]$scenario.raw
    }
  }

  $scenarioIndex = @{}
  for ($i = 0; $i -lt $mergedScenarios.Count; $i++) {
    $scenarioIndex[[string]$mergedScenarios[$i].name] = $i
  }

  foreach ($deltaScenario in $delta.scenarios) {
    $name = [string]$deltaScenario.name
    $raw = [string]$deltaScenario.raw
    if ($scenarioIndex.ContainsKey($name)) {
      $index = [int]$scenarioIndex[$name]
      $mergedScenarios[$index] = [PSCustomObject]@{
        name = $name
        raw = $raw
      }
      continue
    }

    $mergedScenarios += [PSCustomObject]@{
      name = $name
      raw = $raw
    }
    $scenarioIndex[$name] = $mergedScenarios.Count - 1
  }

  return Build-RequirementBlock -Name $canonical.name -Intro $mergedIntro -Scenarios $mergedScenarios
}

function Ensure-CanonicalPrefix {
  param(
    [AllowNull()][string]$Prefix,
    [Parameter(Mandatory = $true)][string]$Capability
  )

  $prefixText = Normalize-MarkdownText -Text $Prefix
  if ([string]::IsNullOrWhiteSpace($prefixText.Trim())) {
    return "# $Capability Specification`n`n## Purpose`nTBD.`n`n## Requirements"
  }

  $trimmed = $prefixText.Trim("`n")
  if ($trimmed -notmatch '(?m)^##\s+Requirements\s*$') {
    $trimmed += "`n`n## Requirements"
  }

  return $trimmed
}

function Get-DeltaSections {
  param([Parameter(Mandatory = $true)][string]$DeltaContent)

  $normalized = Normalize-MarkdownText -Text $DeltaContent
  $sections = @{
    "ADDED" = ""
    "MODIFIED" = ""
    "REMOVED" = ""
    "RENAMED" = ""
  }

  $matches = [regex]::Matches(
    $normalized,
    '(?m)^##\s+(ADDED|MODIFIED|REMOVED|RENAMED)\s+Requirements\s*$'
  )

  for ($i = 0; $i -lt $matches.Count; $i++) {
    $header = [string]$matches[$i].Groups[1].Value.ToUpperInvariant()
    $start = $matches[$i].Index + $matches[$i].Length
    $end = if (($i + 1) -lt $matches.Count) { $matches[$i + 1].Index } else { $normalized.Length }
    $chunk = $normalized.Substring($start, $end - $start).Trim("`n")
    if ([string]::IsNullOrWhiteSpace($chunk)) {
      continue
    }
    if ([string]::IsNullOrWhiteSpace($sections[$header])) {
      $sections[$header] = $chunk
    } else {
      $sections[$header] = ($sections[$header].Trim("`n") + "`n`n" + $chunk)
    }
  }

  return [PSCustomObject]@{
    Added = [string]$sections["ADDED"]
    Modified = [string]$sections["MODIFIED"]
    Removed = [string]$sections["REMOVED"]
    Renamed = [string]$sections["RENAMED"]
  }
}

function Normalize-RequirementReference {
  param([Parameter(Mandatory = $true)][string]$Reference)

  $value = [string]$Reference
  $value = $value.Trim()
  $value = $value -replace '^[`"''\s]+', ''
  $value = $value -replace '[`"''\s]+$', ''
  $value = $value -replace '^\s*###\s*Requirement:\s*', ''
  return $value.Trim()
}

function Parse-RenameOperations {
  param([AllowNull()][string]$SectionContent)

  $normalized = Normalize-MarkdownText -Text $SectionContent
  if ([string]::IsNullOrWhiteSpace($normalized.Trim())) {
    return @()
  }

  $operations = @()
  $pendingFrom = ""
  $lines = $normalized -split "`n"
  foreach ($line in $lines) {
    $trimmed = [string]$line.Trim()
    if ($trimmed -match '^-+\s*FROM:\s*(?<value>.+)$') {
      $pendingFrom = Normalize-RequirementReference -Reference ([string]$matches["value"])
      continue
    }

    if ($trimmed -match '^-+\s*TO:\s*(?<value>.+)$') {
      if ([string]::IsNullOrWhiteSpace($pendingFrom)) {
        throw ("invalid RENAMED section entry without FROM: {0}" -f $trimmed)
      }
      $to = Normalize-RequirementReference -Reference ([string]$matches["value"])
      if ([string]::IsNullOrWhiteSpace($to)) {
        throw ("invalid RENAMED section TO entry: {0}" -f $trimmed)
      }
      $operations += [PSCustomObject]@{
        from = $pendingFrom
        to = $to
      }
      $pendingFrom = ""
      continue
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($pendingFrom)) {
    throw ("invalid RENAMED section; dangling FROM entry: {0}" -f $pendingFrom)
  }

  return @($operations)
}

function Merge-SpecContent {
  param(
    [Parameter(Mandatory = $true)][string]$Capability,
    [Parameter(Mandatory = $true)][string]$DeltaContent,
    [AllowNull()][string]$CanonicalContent
  )

  $deltaSections = Get-DeltaSections -DeltaContent $DeltaContent
  $addedRequirements = @(Get-RequirementBlocks -Text $deltaSections.Added)
  $modifiedRequirements = @(Get-RequirementBlocks -Text $deltaSections.Modified)
  $removedRequirements = @(Get-RequirementBlocks -Text $deltaSections.Removed)
  $renameOperations = @(Parse-RenameOperations -SectionContent $deltaSections.Renamed)

  if (
    $addedRequirements.Count -eq 0 -and
    $modifiedRequirements.Count -eq 0 -and
    $removedRequirements.Count -eq 0 -and
    $renameOperations.Count -eq 0
  ) {
    throw ("delta spec for capability '{0}' contains no recognizable requirement changes." -f $Capability)
  }

  $canonical = Normalize-MarkdownText -Text $CanonicalContent
  $firstRequirement = [regex]::Match($canonical, '(?m)^###\s+Requirement:\s*')
  $prefix = ""
  $requirements = @()

  if ($firstRequirement.Success) {
    $prefix = $canonical.Substring(0, $firstRequirement.Index).Trim("`n")
    $requirements = @(Get-RequirementBlocks -Text $canonical.Substring($firstRequirement.Index))
  } else {
    $prefix = $canonical.Trim("`n")
    $requirements = @()
  }

  $prefix = Ensure-CanonicalPrefix -Prefix $prefix -Capability $Capability

  $summary = [ordered]@{
    added = 0
    modified = 0
    removed = 0
    renamed = 0
  }

  $requirementIndex = @{}
  for ($i = 0; $i -lt $requirements.Count; $i++) {
    $requirementIndex[[string]$requirements[$i].name] = $i
  }

  foreach ($rename in $renameOperations) {
    $from = [string]$rename.from
    $to = [string]$rename.to

    $hasFrom = $requirementIndex.ContainsKey($from)
    $hasTo = $requirementIndex.ContainsKey($to)

    if ($hasFrom -and $hasTo) {
      throw ("cannot rename requirement '{0}' to '{1}': target requirement already exists." -f $from, $to)
    }
    if (-not $hasFrom -and $hasTo) {
      continue
    }
    if (-not $hasFrom -and -not $hasTo) {
      throw ("cannot rename missing requirement '{0}' in capability '{1}'." -f $from, $Capability)
    }

    $idx = [int]$requirementIndex[$from]
    $existing = [string]$requirements[$idx].raw
    $renamedBlock = $existing -replace '(?m)^###\s+Requirement:\s*[^\n]+', ("### Requirement: " + $to)
    $requirements[$idx] = [PSCustomObject]@{
      name = $to
      raw = $renamedBlock.Trim("`n")
    }

    $requirementIndex.Remove($from)
    $requirementIndex[$to] = $idx
    $summary.renamed++
  }

  foreach ($removed in $removedRequirements) {
    $name = [string]$removed.name
    if (-not $requirementIndex.ContainsKey($name)) {
      throw ("cannot remove missing requirement '{0}' in capability '{1}'." -f $name, $Capability)
    }

    $idx = [int]$requirementIndex[$name]
    if ($requirements.Count -le 1) {
      $requirements = @()
    } elseif ($idx -eq 0) {
      $requirements = @($requirements[1..($requirements.Count - 1)])
    } elseif ($idx -eq ($requirements.Count - 1)) {
      $requirements = @($requirements[0..($requirements.Count - 2)])
    } else {
      $requirements = @($requirements[0..($idx - 1)] + $requirements[($idx + 1)..($requirements.Count - 1)])
    }
    $requirementIndex = @{}
    for ($i = 0; $i -lt $requirements.Count; $i++) {
      $requirementIndex[[string]$requirements[$i].name] = $i
    }
    $summary.removed++
  }

  foreach ($modified in $modifiedRequirements) {
    $name = [string]$modified.name
    if (-not $requirementIndex.ContainsKey($name)) {
      throw ("cannot modify missing requirement '{0}' in capability '{1}'." -f $name, $Capability)
    }

    $idx = [int]$requirementIndex[$name]
    $merged = Merge-RequirementBlocks -CanonicalBlock ([string]$requirements[$idx].raw) -DeltaBlock ([string]$modified.raw)
    $requirements[$idx] = [PSCustomObject]@{
      name = $name
      raw = $merged
    }
    $summary.modified++
  }

  foreach ($added in $addedRequirements) {
    $name = [string]$added.name
    if ($requirementIndex.ContainsKey($name)) {
      $idx = [int]$requirementIndex[$name]
      $merged = Merge-RequirementBlocks -CanonicalBlock ([string]$requirements[$idx].raw) -DeltaBlock ([string]$added.raw)
      $requirements[$idx] = [PSCustomObject]@{
        name = $name
        raw = $merged
      }
      $summary.modified++
      continue
    }

    $parsedAdded = Parse-RequirementBlock -RequirementBlock ([string]$added.raw)
    $normalizedAdded = Build-RequirementBlock `
      -Name ([string]$parsedAdded.name) `
      -Intro ([string]$parsedAdded.intro) `
      -Scenarios @($parsedAdded.scenarios)

    $requirements += [PSCustomObject]@{
      name = $name
      raw = $normalizedAdded
    }
    $requirementIndex[$name] = $requirements.Count - 1
    $summary.added++
  }

  $requirementsText = ""
  if ($requirements.Count -gt 0) {
    $requirementsText = (@($requirements | ForEach-Object { ([string]$_.raw).Trim("`n") }) -join "`n`n")
  }

  $final = $prefix.Trim("`n")
  if (-not [string]::IsNullOrWhiteSpace($requirementsText)) {
    $final += "`n`n" + $requirementsText.Trim("`n")
  }
  $final += "`n"

  return [PSCustomObject]@{
    content = $final
    summary = [PSCustomObject]$summary
  }
}

$resolvedChange = Resolve-ChangeName -RequestedChange $Change
$deltaSpecsRoot = Join-Path $repoRoot "openspec\\changes\\$resolvedChange\\specs"

if (-not (Test-Path $deltaSpecsRoot)) {
  throw "delta specs directory not found: $deltaSpecsRoot"
}

$deltaFiles = @(
  Get-ChildItem -Path $deltaSpecsRoot -Recurse -File |
    Where-Object { $_.Name -eq "spec.md" }
)

if ($deltaFiles.Count -eq 0) {
  Write-Host "[migrate-specs] no delta spec files found under openspec/changes/$resolvedChange/specs"
  exit 0
}

$plan = @()
foreach ($deltaFile in $deltaFiles) {
  $capability = [string](Split-Path -Path (Split-Path -Path $deltaFile.FullName -Parent) -Leaf)
  if ([string]::IsNullOrWhiteSpace($capability)) {
    continue
  }

  $targetPath = Join-Path $repoRoot "openspec\\specs\\$capability\\spec.md"
  $action = if (Test-Path $targetPath) { "update" } else { "create" }

  $plan += [PSCustomObject]@{
    capability = $capability
    sourcePath = $deltaFile.FullName
    targetPath = $targetPath
    action = $action
  }
}

if ($plan.Count -eq 0) {
  Write-Host "[migrate-specs] no eligible spec migrations found."
  exit 0
}

Write-Host "## Spec Migration Plan ($resolvedChange)"
foreach ($entry in $plan | Sort-Object capability) {
  $sourceRel = Get-RelativeRepoPath -Root $repoRoot -Path $entry.sourcePath
  $targetRel = Get-RelativeRepoPath -Root $repoRoot -Path $entry.targetPath
  $mode = if ($UnsafeOverwrite) { "overwrite" } else { "merge" }
  Write-Host ("- [{0}] {1}: {2} -> {3} ({4})" -f $entry.action, $entry.capability, $sourceRel, $targetRel, $mode)
}

if (-not $Apply) {
  Write-Host ""
  Write-Host "[migrate-specs] dry-run complete. Re-run with --apply to sync delta specs into openspec/specs."
  exit 0
}

foreach ($entry in $plan) {
  $targetDir = Split-Path -Path $entry.targetPath -Parent
  if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
  }

  $deltaContent = Get-Content -Path $entry.sourcePath -Raw -Encoding UTF8
  if ($UnsafeOverwrite) {
    Set-Content -Path $entry.targetPath -Encoding UTF8 -Value $deltaContent
    Write-Host ("[migrate-specs] {0}: overwrite applied." -f $entry.capability)
    continue
  }

  $canonicalContent = ""
  if (Test-Path $entry.targetPath) {
    $canonicalContent = Get-Content -Path $entry.targetPath -Raw -Encoding UTF8
  }

  $merged = Merge-SpecContent `
    -Capability ([string]$entry.capability) `
    -DeltaContent ([string]$deltaContent) `
    -CanonicalContent ([string]$canonicalContent)

  Set-Content -Path $entry.targetPath -Encoding UTF8 -Value ([string]$merged.content)
  $summary = $merged.summary
  Write-Host (
    "[migrate-specs] {0}: merged (added={1}, modified={2}, removed={3}, renamed={4})." -f
    $entry.capability,
    $summary.added,
    $summary.modified,
    $summary.removed,
    $summary.renamed
  )
}

Write-Host ""
Write-Host ("[migrate-specs] applied {0} spec file(s)." -f $plan.Count)

if (-not $NoValidate) {
  Write-Host "[migrate-specs] running strict OpenSpec validation..."
  Invoke-OpenSpec -Args @("validate", "--all", "--strict", "--no-interactive")
}
