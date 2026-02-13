param(
  [ValidateSet("index", "detail")][string]$Stage = "index",
  [string]$Change = "",
  [string[]]$Ids = @(),
  [ValidateRange(1, 200)][int]$MaxItems = 20,
  [ValidateRange(20, 400)][int]$MaxDetailLines = 120,
  [switch]$NoAudit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Normalize-RepoPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  return ($Path.Trim() -replace "\\", "/")
}

function Resolve-AuditPath {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  if (-not [string]::IsNullOrWhiteSpace($env:WORKFLOW_MEMORY_AUDIT_PATH)) {
    if ([System.IO.Path]::IsPathRooted($env:WORKFLOW_MEMORY_AUDIT_PATH)) {
      return $env:WORKFLOW_MEMORY_AUDIT_PATH
    }
    return (Join-Path $RepoRoot $env:WORKFLOW_MEMORY_AUDIT_PATH)
  }

  $relativePath = ".metrics/memory-context-audit.jsonl"
  $policyPath = Join-Path $RepoRoot "workflow-policy.json"
  if (Test-Path $policyPath) {
    try {
      $policy = Get-Content -Path $policyPath -Encoding UTF8 | ConvertFrom-Json
      if ($null -ne $policy.telemetry -and -not [string]::IsNullOrWhiteSpace([string]$policy.telemetry.memoryContextAuditPath)) {
        $relativePath = [string]$policy.telemetry.memoryContextAuditPath
      }
    } catch {
      # Keep fallback path.
    }
  }

  if ([System.IO.Path]::IsPathRooted($relativePath)) {
    return $relativePath
  }
  return (Join-Path $RepoRoot $relativePath)
}

function Get-BranchOwner {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $branch = (git -C $RepoRoot rev-parse --abbrev-ref HEAD | Select-Object -First 1).Trim()
  if ($branch -match "^sbk-(?<owner>[a-z0-9]+)-(?<change>[a-z0-9][a-z0-9-]*)$") {
    return [ordered]@{
      owner = [string]$Matches["owner"]
      branch = $branch
      change = [string]$Matches["change"]
    }
  }

  return [ordered]@{
    owner = ""
    branch = $branch
    change = ""
  }
}

function Get-FirstNonEmptyLine {
  param([Parameter(Mandatory = $true)][string]$FilePath)

  if (-not (Test-Path $FilePath)) { return "" }
  $lines = Get-Content -Path $FilePath -Encoding UTF8
  foreach ($line in $lines) {
    $trimmed = $line.Trim()
    if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
      return $trimmed
    }
  }
  return ""
}

function Add-Candidate {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Candidates,
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$RepoRelativePath,
    [Parameter(Mandatory = $true)][string]$Category
  )

  $normalizedPath = Normalize-RepoPath -Path $RepoRelativePath
  $fullPath = Join-Path $RepoRoot ($normalizedPath -replace "/", "\")
  if (-not (Test-Path $fullPath)) {
    return
  }

  $existing = @($Candidates | Where-Object { $_.path -eq $normalizedPath }).Count -gt 0
  if ($existing) {
    return
  }

  $summary = Get-FirstNonEmptyLine -FilePath $fullPath
  $item = Get-Item -Path $fullPath
  $Candidates.Add([ordered]@{
      path = $normalizedPath
      category = $Category
      summary = $summary
      lastModifiedUtc = $item.LastWriteTimeUtc.ToString("o")
    }) | Out-Null
}

function Resolve-ChangeName {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $false)][string]$RequestedChange,
    [Parameter(Mandatory = $false)][AllowEmptyString()][string]$BranchChange = ""
  )

  if (-not [string]::IsNullOrWhiteSpace($RequestedChange)) {
    return $RequestedChange.Trim()
  }
  if (-not [string]::IsNullOrWhiteSpace($BranchChange)) {
    return $BranchChange.Trim()
  }

  $changesRoot = Join-Path $RepoRoot "openspec\\changes"
  if (-not (Test-Path $changesRoot)) {
    return ""
  }
  $active = @(Get-ChildItem -Path $changesRoot -Directory | Where-Object { $_.Name -ne "archive" })
  if ($active.Count -eq 1) {
    return $active[0].Name
  }
  return ""
}

$branchInfo = Get-BranchOwner -RepoRoot $repoRoot
$changeName = Resolve-ChangeName -RepoRoot $repoRoot -RequestedChange $Change -BranchChange $branchInfo.change

$candidates = New-Object 'System.Collections.Generic.List[object]'

$coreSources = @(
  ".trellis/spec/guides/constitution.md",
  ".trellis/spec/guides/memory-governance.md",
  ".trellis/spec/guides/quality-gates.md",
  "workflow-policy.json",
  "xxx_docs/README.md",
  "README.md",
  "AGENTS.md",
  ".trellis/workflow.md"
)

foreach ($source in $coreSources) {
  Add-Candidate -Candidates $candidates -RepoRoot $repoRoot -RepoRelativePath $source -Category "core"
}

if (-not [string]::IsNullOrWhiteSpace($changeName)) {
  Add-Candidate -Candidates $candidates -RepoRoot $repoRoot -RepoRelativePath "openspec/changes/$changeName/proposal.md" -Category "change"
  Add-Candidate -Candidates $candidates -RepoRoot $repoRoot -RepoRelativePath "openspec/changes/$changeName/design.md" -Category "change"
  Add-Candidate -Candidates $candidates -RepoRoot $repoRoot -RepoRelativePath "openspec/changes/$changeName/tasks.md" -Category "change"

  $deltaRoot = Join-Path $repoRoot ("openspec\\changes\\$changeName\\specs")
  if (Test-Path $deltaRoot) {
    $deltaSpecs = @(Get-ChildItem -Path $deltaRoot -Recurse -File -Filter "spec.md")
    foreach ($spec in $deltaSpecs) {
      $relative = Normalize-RepoPath -Path $spec.FullName.Substring($repoRoot.Length).TrimStart("\")
      Add-Candidate -Candidates $candidates -RepoRoot $repoRoot -RepoRelativePath $relative -Category "change-spec"
    }
  }
}

if (-not [string]::IsNullOrWhiteSpace($branchInfo.owner)) {
  $ownerRoot = Join-Path $repoRoot (".trellis\\workspace\\$($branchInfo.owner)")
  if (Test-Path $ownerRoot) {
    Add-Candidate -Candidates $candidates -RepoRoot $repoRoot -RepoRelativePath ".trellis/workspace/$($branchInfo.owner)/index.md" -Category "owner-workspace"

    $journals = @(Get-ChildItem -Path $ownerRoot -File -Filter "journal-*.md" | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 2)
    foreach ($journal in $journals) {
      $relative = Normalize-RepoPath -Path $journal.FullName.Substring($repoRoot.Length).TrimStart("\")
      Add-Candidate -Candidates $candidates -RepoRoot $repoRoot -RepoRelativePath $relative -Category "owner-journal"
    }
  }
}

$sortedCandidates = @($candidates | Sort-Object category, path)
$indexedCandidates = @()
$indexCounter = 1
foreach ($candidate in $sortedCandidates) {
  $id = ("S{0:000}" -f $indexCounter)
  $indexCounter += 1
  $indexedCandidates += [ordered]@{
    id = $id
    path = $candidate.path
    category = $candidate.category
    summary = $candidate.summary
    lastModifiedUtc = $candidate.lastModifiedUtc
  }
}

$result = [ordered]@{
  generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
  stage = $Stage
  branch = $branchInfo.branch
  owner = $branchInfo.owner
  change = $changeName
  requestedIds = @()
}

if ($Stage -eq "index") {
  $result.count = [Math]::Min($MaxItems, $indexedCandidates.Count)
  $result.sources = @($indexedCandidates | Select-Object -First $MaxItems)
} else {
  if ($Ids.Count -eq 0) {
    throw "Stage 'detail' requires at least one id via -Ids."
  }

  $expandedIds = @()
  foreach ($rawId in $Ids) {
    foreach ($part in ([string]$rawId).Split(",")) {
      $trimmedPart = $part.Trim()
      if (-not [string]::IsNullOrWhiteSpace($trimmedPart)) {
        $expandedIds += $trimmedPart
      }
    }
  }

  if ($expandedIds.Count -eq 0) {
    throw "Stage 'detail' requires valid non-empty IDs."
  }

  $selectedSources = @()
  $missing = @()
  foreach ($id in $expandedIds) {
    $trimmedId = $id.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmedId)) { continue }

    $source = @($indexedCandidates | Where-Object { $_.id.Equals($trimmedId, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1)
    if ($source.Count -eq 0) {
      $missing += $trimmedId
      continue
    }

    $path = [string]$source[0].path
    $fullPath = Join-Path $repoRoot ($path -replace "/", "\")
    $previewLines = @()
    if (Test-Path $fullPath) {
      $previewLines = @(Get-Content -Path $fullPath -Encoding UTF8 | Select-Object -First $MaxDetailLines)
    }

    $selectedSources += [ordered]@{
      id = [string]$source[0].id
      path = $path
      category = [string]$source[0].category
      lineCount = $previewLines.Count
      excerpt = $previewLines -join "`n"
    }
  }

  $result.requestedIds = @($expandedIds)
  $result.missingIds = @($missing | Select-Object -Unique)
  $result.count = $selectedSources.Count
  $result.sources = $selectedSources
}

if (-not $NoAudit) {
  $auditPath = Resolve-AuditPath -RepoRoot $repoRoot
  $auditDir = Split-Path -Path $auditPath -Parent
  if (-not (Test-Path $auditDir)) {
    New-Item -ItemType Directory -Path $auditDir | Out-Null
  }

  $auditRecord = [ordered]@{
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    stage = $Stage
    branch = $branchInfo.branch
    owner = $branchInfo.owner
    change = $changeName
    requestedIds = @($result.requestedIds)
    selectedCount = [int]$result.count
    totalCandidates = $indexedCandidates.Count
    sourceIds = @($result.sources | ForEach-Object { [string]$_.id })
  }
  Add-Content -Path $auditPath -Value ($auditRecord | ConvertTo-Json -Depth 8 -Compress)
}

$result | ConvertTo-Json -Depth 8
