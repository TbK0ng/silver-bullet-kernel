param(
  [ValidateSet("local", "ci")][string]$Mode = "local",
  [string]$BaseRef = "",
  [switch]$NoReport,
  [switch]$FailOnWarning,
  [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$docsGeneratedDir = Join-Path $repoRoot "xxx_docs\\generated"
$reportMd = Join-Path $docsGeneratedDir "workflow-policy-gate.md"
$reportJson = Join-Path $docsGeneratedDir "workflow-policy-gate.json"

function Add-Check {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Checks,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][ValidateSet("fail", "warn")][string]$Severity,
    [Parameter(Mandatory = $true)][bool]$Passed,
    [Parameter(Mandatory = $true)][string]$Details,
    [Parameter(Mandatory = $true)][string]$Remediation
  )

  $Checks.Add([PSCustomObject]@{
      name = $Name
      severity = $Severity
      passed = $Passed
      details = $Details
      remediation = $Remediation
    }) | Out-Null
}

function Normalize-RepoPath {
  param(
    [Parameter(Mandatory = $true)][string]$Path
  )
  return ($Path.Trim() -replace "\\", "/")
}

function Test-PathMatch {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string[]]$Prefixes,
    [Parameter(Mandatory = $true)][string[]]$ExactFiles
  )
  foreach ($prefix in $Prefixes) {
    if ($Path.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }
  foreach ($exactFile in $ExactFiles) {
    if ($Path.Equals($exactFile, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }
  return $false
}

function Get-WorkingTreeFiles {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot
  )

  $lines = @(git -C $RepoRoot status --porcelain=v1)
  $files = @()
  foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line.Length -lt 4) { continue }

    $pathPart = $line.Substring(3).Trim()
    if ($pathPart.Contains("->")) {
      $segments = $pathPart.Split("->")
      $pathPart = $segments[$segments.Length - 1].Trim()
    }

    $files += Normalize-RepoPath -Path $pathPart
  }
  return @($files | Select-Object -Unique)
}

function Get-BranchDeltaInfo {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $false)][string]$BaseRefArg
  )

  $resolvedBaseRef = $BaseRefArg
  if ([string]::IsNullOrWhiteSpace($resolvedBaseRef)) {
    $resolvedBaseRef = $env:WORKFLOW_BASE_REF
  }
  if ([string]::IsNullOrWhiteSpace($resolvedBaseRef) -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_BASE_REF)) {
    $resolvedBaseRef = "origin/$($env:GITHUB_BASE_REF.Trim())"
  }
  if ([string]::IsNullOrWhiteSpace($resolvedBaseRef)) {
    git -C $RepoRoot rev-parse --verify --quiet origin/main *> $null
    if ($LASTEXITCODE -eq 0) {
      $resolvedBaseRef = "origin/main"
    }
  }

  if ([string]::IsNullOrWhiteSpace($resolvedBaseRef)) {
    return [ordered]@{
      available = $false
      reason = "No base ref available (set WORKFLOW_BASE_REF or ensure origin base branch is fetched)."
      baseRef = ""
      mergeBase = ""
      files = @()
    }
  }

  $mergeBase = (git -C $RepoRoot merge-base HEAD $resolvedBaseRef | Select-Object -First 1)
  if ([string]::IsNullOrWhiteSpace($mergeBase)) {
    return [ordered]@{
      available = $false
      reason = "Unable to resolve merge-base for '$resolvedBaseRef'."
      baseRef = $resolvedBaseRef
      mergeBase = ""
      files = @()
    }
  }

  $files = @(git -C $RepoRoot diff --name-only "$mergeBase..HEAD" |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      ForEach-Object { Normalize-RepoPath -Path $_ })

  return [ordered]@{
    available = $true
    reason = ""
    baseRef = $resolvedBaseRef
    mergeBase = $mergeBase.Trim()
    files = @($files | Select-Object -Unique)
  }
}

function Get-ImplementationFiles {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Files,
    [Parameter(Mandatory = $true)][string[]]$IgnorePrefixes,
    [Parameter(Mandatory = $true)][string[]]$ImplementationPrefixes,
    [Parameter(Mandatory = $true)][string[]]$ImplementationFilesExact
  )

  $result = @()
  foreach ($file in $Files) {
    $ignored = $false
    foreach ($ignorePrefix in $IgnorePrefixes) {
      if ($file.StartsWith($ignorePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $ignored = $true
        break
      }
    }
    if ($ignored) { continue }

    if (Test-PathMatch -Path $file -Prefixes $ImplementationPrefixes -ExactFiles $ImplementationFilesExact) {
      $result += $file
    }
  }
  return @($result | Select-Object -Unique)
}

function Get-CurrentBranchName {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot
  )

  $branch = (git -C $RepoRoot rev-parse --abbrev-ref HEAD | Select-Object -First 1).Trim()
  if ($branch -eq "HEAD") {
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_HEAD_REF)) {
      return $env:GITHUB_HEAD_REF.Trim()
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_REF_NAME)) {
      return $env:GITHUB_REF_NAME.Trim()
    }
  }
  return $branch
}

function Get-BranchIdentity {
  param(
    [Parameter(Mandatory = $true)][string]$BranchName,
    [Parameter(Mandatory = $true)][string]$BranchPattern
  )

  if ([string]::IsNullOrWhiteSpace($BranchName)) {
    return [ordered]@{
      valid = $false
      branch = $BranchName
      owner = ""
      change = ""
      reason = "Branch name is empty."
    }
  }

  $regex = [regex]::new($BranchPattern)
  $match = $regex.Match($BranchName)
  if (-not $match.Success) {
    return [ordered]@{
      valid = $false
      branch = $BranchName
      owner = ""
      change = ""
      reason = "Branch name does not match pattern '$BranchPattern'."
    }
  }

  $owner = ""
  $change = ""
  try {
    $owner = [string]$match.Groups["owner"].Value
    $change = [string]$match.Groups["change"].Value
  } catch {
    $owner = ""
    $change = ""
  }

  if ([string]::IsNullOrWhiteSpace($owner) -or [string]::IsNullOrWhiteSpace($change)) {
    return [ordered]@{
      valid = $false
      branch = $BranchName
      owner = $owner
      change = $change
      reason = "Pattern must provide non-empty named groups 'owner' and 'change'."
    }
  }

  return [ordered]@{
    valid = $true
    branch = $BranchName
    owner = $owner
    change = $change
    reason = ""
  }
}

function Get-GitDirInfo {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$LinkedMarker
  )

  $gitDirRaw = (git -C $RepoRoot rev-parse --git-dir | Select-Object -First 1).Trim()
  $gitDirFull = $gitDirRaw
  if (-not [System.IO.Path]::IsPathRooted($gitDirRaw)) {
    $gitDirFull = Join-Path $RepoRoot $gitDirRaw
  }
  $normalized = (Normalize-RepoPath -Path $gitDirFull).ToLowerInvariant()
  $marker = $LinkedMarker.ToLowerInvariant()
  $isLinked = $normalized.Contains($marker)

  return [ordered]@{
    gitDirRaw = $gitDirRaw
    gitDirFull = $gitDirFull
    isLinkedWorktree = $isLinked
  }
}

function Join-PathsForDetails {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Paths,
    [int]$MaxItems = 8
  )
  if ($Paths.Count -eq 0) { return "none" }
  $picked = @($Paths | Select-Object -First $MaxItems)
  $suffix = ""
  if ($Paths.Count -gt $MaxItems) {
    $suffix = " (+$($Paths.Count - $MaxItems) more)"
  }
  return ($picked -join ", ") + $suffix
}

$configPath = Join-Path $repoRoot "workflow-policy.json"
if (-not (Test-Path $configPath)) {
  throw "workflow policy config missing: $configPath"
}
$config = Get-Content -Path $configPath -Encoding UTF8 | ConvertFrom-Json

$implementationPrefixes = @($config.workflowGate.implementationPathPrefixes)
$implementationFilesExact = @($config.workflowGate.implementationPathFiles)
$ignorePrefixes = @($config.workflowGate.ignorePathPrefixes)
$branchPattern = [string]$config.workflowGate.branchPattern
$ownerWorkspaceRoot = [string]$config.workflowGate.ownerWorkspaceRoot
if ([string]::IsNullOrWhiteSpace($ownerWorkspaceRoot)) {
  $ownerWorkspaceRoot = ".trellis/workspace/"
}
$linkedMarker = [string]$config.workflowGate.linkedWorktreeGitDirContains
if ([string]::IsNullOrWhiteSpace($linkedMarker)) {
  $linkedMarker = "/.git/worktrees/"
}

$currentBranch = Get-CurrentBranchName -RepoRoot $repoRoot
$branchIdentity = Get-BranchIdentity -BranchName $currentBranch -BranchPattern $branchPattern
$gitDirInfo = Get-GitDirInfo -RepoRoot $repoRoot -LinkedMarker $linkedMarker

$workingTreeFiles = @(Get-WorkingTreeFiles -RepoRoot $repoRoot)
$workingImplementationFiles = @(Get-ImplementationFiles `
    -Files $workingTreeFiles `
    -IgnorePrefixes $ignorePrefixes `
    -ImplementationPrefixes $implementationPrefixes `
    -ImplementationFilesExact $implementationFilesExact)

$changesDir = Join-Path $repoRoot "openspec\\changes"
$activeChanges = @()
if (Test-Path $changesDir) {
  $activeChanges = @(Get-ChildItem -Path $changesDir -Directory | Where-Object { $_.Name -ne "archive" })
}
$activeChangeNames = @($activeChanges | ForEach-Object { $_.Name })

$workingHasArchiveArtifacts = @($workingTreeFiles | Where-Object {
    $_.StartsWith("openspec/changes/archive/", [System.StringComparison]::OrdinalIgnoreCase)
  }).Count -gt 0
$workingHasAnyChangeArtifacts = @($workingTreeFiles | Where-Object {
    $_.StartsWith("openspec/changes/", [System.StringComparison]::OrdinalIgnoreCase)
  }).Count -gt 0

$checks = New-Object 'System.Collections.Generic.List[object]'

if ([bool]$config.workflowGate.requireActiveChangeForImplementationEdits) {
  $activeOrArchiveOk = ($activeChanges.Count -gt 0) -or $workingHasArchiveArtifacts
  $needsMapping = $workingImplementationFiles.Count -gt 0
  Add-Check -Checks $checks `
    -Name "Implementation edits require active change or archive artifacts" `
    -Severity "fail" `
    -Passed ((-not $needsMapping) -or $activeOrArchiveOk) `
    -Details ("implementation_files=$($workingImplementationFiles.Count); active_changes=$($activeChanges.Count); has_archive_artifacts=$workingHasArchiveArtifacts; files=" + (Join-PathsForDetails -Paths $workingImplementationFiles)) `
    -Remediation "Create an OpenSpec change (`openspec new change <name>`) and complete artifacts before implementation, or archive completed change properly."
}

if ([bool]$config.workflowGate.requireCompleteActiveChangeArtifacts) {
  foreach ($change in $activeChanges) {
    $proposal = Join-Path $change.FullName "proposal.md"
    $design = Join-Path $change.FullName "design.md"
    $tasks = Join-Path $change.FullName "tasks.md"
    $deltaSpecs = @()
    $specRoot = Join-Path $change.FullName "specs"
    if (Test-Path $specRoot) {
      $deltaSpecs = @(Get-ChildItem -Path $specRoot -Recurse -File -Filter "spec.md")
    }
    $complete = (Test-Path $proposal) -and (Test-Path $design) -and (Test-Path $tasks) -and ($deltaSpecs.Count -gt 0)
    Add-Check -Checks $checks `
      -Name "Active change '$($change.Name)' has complete artifacts" `
      -Severity "fail" `
      -Passed $complete `
      -Details ("proposal=$(Test-Path $proposal); design=$(Test-Path $design); tasks=$(Test-Path $tasks); delta_specs=$($deltaSpecs.Count)") `
      -Remediation "Ensure proposal.md, design.md, tasks.md, and at least one spec delta file exist under the active change."
  }
}

$workingCanonicalSpecs = @($workingTreeFiles | Where-Object {
    $_.StartsWith("openspec/specs/", [System.StringComparison]::OrdinalIgnoreCase)
  })
Add-Check -Checks $checks `
  -Name "Canonical specs updated only via archive flow" `
  -Severity "fail" `
  -Passed (($workingCanonicalSpecs.Count -eq 0) -or $workingHasArchiveArtifacts) `
  -Details ("canonical_spec_files=$($workingCanonicalSpecs.Count); has_archive_artifacts=$workingHasArchiveArtifacts; files=" + (Join-PathsForDetails -Paths $workingCanonicalSpecs)) `
  -Remediation "Avoid direct canonical spec edits during active implementation; use change deltas and `openspec archive` to merge."

$branchDelta = Get-BranchDeltaInfo -RepoRoot $repoRoot -BaseRefArg $BaseRef
$branchImplementationFiles = @()
if ([bool]$branchDelta.available) {
  $branchImplementationFiles = @(Get-ImplementationFiles `
      -Files $branchDelta.files `
      -IgnorePrefixes $ignorePrefixes `
      -ImplementationPrefixes $implementationPrefixes `
      -ImplementationFilesExact $implementationFilesExact)
}
$branchHasArchiveArtifacts = @($branchDelta.files | Where-Object {
    $_.StartsWith("openspec/changes/archive/", [System.StringComparison]::OrdinalIgnoreCase)
  }).Count -gt 0
$implementationFilesForMode = if ($Mode -eq "ci") { @($branchImplementationFiles) } else { @($workingImplementationFiles) }
$hasArchiveContextForMode = if ($Mode -eq "ci") { $branchHasArchiveArtifacts } else { $workingHasArchiveArtifacts }
$needsOwnerContext = @($implementationFilesForMode).Count -gt 0

if ([bool]$config.workflowGate.requireBranchPatternForImplementationEdits) {
  Add-Check -Checks $checks `
    -Name "Implementation branch matches owner/change pattern" `
    -Severity "fail" `
    -Passed ((-not $needsOwnerContext) -or [bool]$branchIdentity.valid) `
    -Details ("branch=$currentBranch; valid=$($branchIdentity.valid); owner=$($branchIdentity.owner); change=$($branchIdentity.change); reason=$($branchIdentity.reason)") `
    -Remediation "Use branch format from workflow policy config (for example: sbk-codex-<change>)."
}

if ([bool]$config.workflowGate.requireSingleActiveChangeForImplementationEdits) {
  $mustHaveSingleActive = $needsOwnerContext -and (-not $hasArchiveContextForMode)
  Add-Check -Checks $checks `
    -Name "Implementation scope maps to exactly one active change" `
    -Severity "fail" `
    -Passed ((-not $mustHaveSingleActive) -or ($activeChanges.Count -eq 1)) `
    -Details ("active_changes=$($activeChanges.Count); has_archive_context=$hasArchiveContextForMode") `
    -Remediation "Keep one active OpenSpec change per implementation branch."
}

if ([bool]$config.workflowGate.requireBranchChangeMatchesActiveChange) {
  $mustMatchActiveChange = $needsOwnerContext -and ($activeChanges.Count -eq 1) -and [bool]$branchIdentity.valid
  $activeName = if ($activeChanges.Count -eq 1) { $activeChanges[0].Name } else { "" }
  $matches = $false
  if ($mustMatchActiveChange) {
    $matches = $branchIdentity.change.Equals($activeName, [System.StringComparison]::OrdinalIgnoreCase)
  }
  Add-Check -Checks $checks `
    -Name "Branch change id matches active change" `
    -Severity "fail" `
    -Passed ((-not $mustMatchActiveChange) -or $matches) `
    -Details ("branch_change=$($branchIdentity.change); active_change=$activeName") `
    -Remediation "Rename branch or active change so branch `<change>` segment matches active OpenSpec change id."
}

if ($Mode -eq "local" -and [bool]$config.workflowGate.requireLinkedWorktreeForLocalImplementation) {
  $mustBeLinked = $workingImplementationFiles.Count -gt 0
  Add-Check -Checks $checks `
    -Name "Local implementation runs from linked worktree" `
    -Severity "fail" `
    -Passed ((-not $mustBeLinked) -or [bool]$gitDirInfo.isLinkedWorktree) `
    -Details ("git_dir_raw=$($gitDirInfo.gitDirRaw); git_dir_full=$($gitDirInfo.gitDirFull); is_linked=$($gitDirInfo.isLinkedWorktree)") `
    -Remediation "Run implementation in linked worktree (`git worktree add`) using one branch per change."
}

if ($Mode -eq "local" -and [bool]$config.workflowGate.requireOwnerScopedSessionEvidence) {
  $needsLocalSessionEvidence = $workingImplementationFiles.Count -gt 0
  $ownerPrefix = if ([bool]$branchIdentity.valid) { "$ownerWorkspaceRoot$($branchIdentity.owner)/" } else { "" }
  $hasOwnerSessionEvidence = $false
  if (-not [string]::IsNullOrWhiteSpace($ownerPrefix)) {
    $hasOwnerSessionEvidence = @($workingTreeFiles | Where-Object {
        $_.StartsWith($ownerPrefix, [System.StringComparison]::OrdinalIgnoreCase)
      }).Count -gt 0
  }
  Add-Check -Checks $checks `
    -Name "Local implementation includes owner-scoped session evidence" `
    -Severity "fail" `
    -Passed ((-not $needsLocalSessionEvidence) -or ([bool]$branchIdentity.valid -and $hasOwnerSessionEvidence)) `
    -Details ("owner_prefix=$ownerPrefix; has_owner_session_evidence=$hasOwnerSessionEvidence") `
    -Remediation "Update session evidence under $ownerPrefix before verify."
}

$ciFailClosed = ($Mode -eq "ci" -and [bool]$config.workflowGate.ciRequireResolvableBaseRef)
$branchDeltaAvailabilitySeverity = if ($ciFailClosed) { "fail" } else { "warn" }
$branchRuleSeverity = if ($Mode -eq "ci") { "fail" } else { "warn" }
Add-Check -Checks $checks `
  -Name "Branch delta available for governance checks" `
  -Severity $branchDeltaAvailabilitySeverity `
  -Passed ([bool]$branchDelta.available) `
  -Details ("available=$($branchDelta.available); base_ref=$($branchDelta.baseRef); merge_base=$($branchDelta.mergeBase); reason=$($branchDelta.reason)") `
  -Remediation "Set WORKFLOW_BASE_REF and ensure base branch history is fetched in CI."

if ([bool]$branchDelta.available -and [bool]$config.workflowGate.requireChangeArtifactsInBranchDelta) {
  $branchNeedsMapping = $branchImplementationFiles.Count -gt 0
  $branchHasChangeArtifacts = @($branchDelta.files | Where-Object {
      $_.StartsWith("openspec/changes/", [System.StringComparison]::OrdinalIgnoreCase)
    }).Count -gt 0
  Add-Check -Checks $checks `
    -Name "Branch implementation delta includes OpenSpec change artifacts" `
    -Severity $branchRuleSeverity `
    -Passed ((-not $branchNeedsMapping) -or $branchHasChangeArtifacts) `
    -Details ("implementation_files=$($branchImplementationFiles.Count); has_change_artifacts=$branchHasChangeArtifacts; files=" + (Join-PathsForDetails -Paths $branchImplementationFiles)) `
    -Remediation "Ensure branch includes `openspec/changes/<name>/` artifacts for implementation changes."
}

if ([bool]$branchDelta.available -and [bool]$config.workflowGate.requireSessionRecordInBranchDelta) {
  $branchNeedsSessionEvidence = $branchImplementationFiles.Count -gt 0
  $expectedOwnerPrefix = if ([bool]$branchIdentity.valid) { "$ownerWorkspaceRoot$($branchIdentity.owner)/" } else { ".trellis/workspace/" }
  $branchHasSessionEvidence = @($branchDelta.files | Where-Object {
      $_.StartsWith($expectedOwnerPrefix, [System.StringComparison]::OrdinalIgnoreCase)
    }).Count -gt 0
  $sessionCheckPassed = if ([bool]$config.workflowGate.requireOwnerScopedSessionEvidence) {
    ((-not $branchNeedsSessionEvidence) -or ([bool]$branchIdentity.valid -and $branchHasSessionEvidence))
  } else {
    ((-not $branchNeedsSessionEvidence) -or $branchHasSessionEvidence)
  }
  Add-Check -Checks $checks `
    -Name "Branch implementation delta includes session evidence" `
    -Severity $branchRuleSeverity `
    -Passed $sessionCheckPassed `
    -Details ("implementation_files=$($branchImplementationFiles.Count); expected_owner_prefix=$expectedOwnerPrefix; has_session_evidence=$branchHasSessionEvidence") `
    -Remediation "Record session evidence under owner workspace path before merge."
}

$failedChecks = @($checks | Where-Object { -not $_.passed -and $_.severity -eq "fail" })
$warningChecks = @($checks | Where-Object { -not $_.passed -and $_.severity -eq "warn" })
$outcome = if ($failedChecks.Count -gt 0) { "FAIL" } elseif ($warningChecks.Count -gt 0) { "WARN" } else { "PASS" }

$summary = [ordered]@{
  generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
  mode = $Mode
  outcome = $outcome
  currentBranch = $currentBranch
  branchIdentity = $branchIdentity
  gitDirInfo = $gitDirInfo
  branchDelta = $branchDelta
  activeChanges = $activeChangeNames
  workingImplementationFiles = $workingImplementationFiles
  checks = @($checks | ForEach-Object {
      [ordered]@{
        name = [string]$_.name
        severity = [string]$_.severity
        passed = [bool]$_.passed
        details = [string]$_.details
        remediation = [string]$_.remediation
      }
    })
}

if (-not $NoReport) {
  if (-not (Test-Path $docsGeneratedDir)) {
    New-Item -ItemType Directory -Path $docsGeneratedDir | Out-Null
  }

  $lines = @()
  $lines += "# Workflow Policy Gate"
  $lines += ""
  $lines += "- generated_at_utc: $([DateTimeOffset]::UtcNow.ToString("u"))"
  $lines += "- mode: $Mode"
  $lines += "- outcome: $outcome"
  $lines += "- active_changes: $(if ($activeChangeNames.Count -eq 0) { "none" } else { $activeChangeNames -join ", " })"
  $lines += ""
  $lines += "## Checks"
  $lines += ""
  $lines += "| Check | Severity | Status | Details | Remediation |"
  $lines += "| --- | --- | --- | --- | --- |"
  foreach ($check in $checks) {
    $status = if ($check.passed) { "PASS" } else { "FAIL" }
    $lines += "| $($check.name) | $($check.severity) | $status | $($check.details) | $($check.remediation) |"
  }

  Set-Content -Path $reportMd -Encoding UTF8 -Value $lines
  Set-Content -Path $reportJson -Encoding UTF8 -Value ($summary | ConvertTo-Json -Depth 10)
}

if (-not $Quiet) {
  Write-Host "[workflow-policy-gate] mode=$Mode outcome=$outcome fail=$($failedChecks.Count) warn=$($warningChecks.Count)"
}

if ($failedChecks.Count -gt 0) {
  throw "workflow policy gate failed"
}
if ($FailOnWarning -and $warningChecks.Count -gt 0) {
  throw "workflow policy gate warning escalated to failure"
}
