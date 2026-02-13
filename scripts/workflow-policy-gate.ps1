param(
  [ValidateSet("local", "ci")][string]$Mode = "local",
  [string]$BaseRef = "",
  [string]$TargetConfigPath = "",
  [string]$Adapter = "",
  [string]$Profile = "",
  [switch]$NoReport,
  [switch]$FailOnWarning,
  [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "common\\sbk-runtime.ps1")

$runtime = Get-SbkRuntimeContext `
  -SbkRoot $repoRoot `
  -TargetConfigPath $TargetConfigPath `
  -AdapterOverride $Adapter `
  -ProfileOverride $Profile

$metricsOutputDir = Join-Path $repoRoot ".metrics"
$reportMd = Join-Path $metricsOutputDir "workflow-policy-gate.md"
$reportJson = Join-Path $metricsOutputDir "workflow-policy-gate.json"

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

  $lines = @(git -c core.quotepath=false -C $RepoRoot status --porcelain=v1)
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
    [Parameter(Mandatory = $false)][string]$BaseRefArg,
    [Parameter(Mandatory = $false)][string]$GateMode = "local"
  )

  $headSha = (git -C $RepoRoot rev-parse HEAD | Select-Object -First 1).Trim()
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
      baseSha = ""
      headSha = $headSha
      mergeBase = ""
      files = @()
    }
  }

  $baseShaRaw = [string](git -C $RepoRoot rev-parse --verify --quiet $resolvedBaseRef | Select-Object -First 1)
  $baseSha = $baseShaRaw.Trim()
  if ([string]::IsNullOrWhiteSpace($baseSha)) {
    return [ordered]@{
      available = $false
      reason = "Unable to resolve base ref '$resolvedBaseRef'."
      baseRef = $resolvedBaseRef
      baseSha = ""
      headSha = $headSha
      mergeBase = ""
      files = @()
    }
  }

  if ($GateMode -eq "ci" -and $baseSha.Equals($headSha, [System.StringComparison]::OrdinalIgnoreCase)) {
    return [ordered]@{
      available = $false
      reason = "Base ref '$resolvedBaseRef' resolves to current HEAD; branch delta is degenerate."
      baseRef = $resolvedBaseRef
      baseSha = $baseSha
      headSha = $headSha
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
      baseSha = $baseSha
      headSha = $headSha
      mergeBase = ""
      files = @()
    }
  }

  $files = @(git -c core.quotepath=false -C $RepoRoot diff --name-only "$mergeBase..HEAD" |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      ForEach-Object { Normalize-RepoPath -Path $_ })

  return [ordered]@{
    available = $true
    reason = ""
    baseRef = $resolvedBaseRef
    baseSha = $baseSha
    headSha = $headSha
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

function Split-MarkdownTableColumns {
  param(
    [Parameter(Mandatory = $true)][string]$Line
  )

  return @($Line.Trim().Trim("|").Split("|") | ForEach-Object { $_.Trim() })
}

function Get-TaskEvidenceTable {
  param(
    [Parameter(Mandatory = $true)][string]$TasksPath,
    [Parameter(Mandatory = $true)][string]$RequiredHeading
  )

  if (-not (Test-Path $TasksPath)) {
    return [ordered]@{
      found = $false
      reason = "tasks.md missing"
      header = @()
      rows = @()
      headingLine = -1
    }
  }

  $lines = Get-Content -Path $TasksPath -Encoding UTF8
  $headingLine = -1
  $headingRegex = "^\s*#{1,6}\s*" + [regex]::Escape($RequiredHeading) + "\s*$"

  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match $headingRegex) {
      $headingLine = $i
      break
    }
  }

  if ($headingLine -lt 0) {
    return [ordered]@{
      found = $false
      reason = "Required heading '$RequiredHeading' not found."
      header = @()
      rows = @()
      headingLine = -1
    }
  }

  $headerColumns = @()
  $rows = @()
  $tableStarted = $false
  $separatorSeen = $false

  for ($lineIndex = $headingLine + 1; $lineIndex -lt $lines.Count; $lineIndex++) {
    $trimmed = $lines[$lineIndex].Trim()
    if ($trimmed.StartsWith("#")) {
      break
    }
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
      if ($tableStarted) { break }
      continue
    }
    if (-not $trimmed.StartsWith("|")) {
      if ($tableStarted) { break }
      continue
    }

    if (-not $tableStarted) {
      $tableStarted = $true
      $headerColumns = Split-MarkdownTableColumns -Line $trimmed
      continue
    }

    if (-not $separatorSeen) {
      if ($trimmed -match "^\|\s*[-: ]+\|") {
        $separatorSeen = $true
        continue
      }

      return [ordered]@{
        found = $false
        reason = "Task evidence table is missing markdown separator row."
        header = $headerColumns
        rows = @()
        headingLine = $headingLine + 1
      }
    }

    $rows += ,(Split-MarkdownTableColumns -Line $trimmed)
  }

  if (-not $tableStarted) {
    return [ordered]@{
      found = $false
      reason = "No markdown table found under heading '$RequiredHeading'."
      header = @()
      rows = @()
      headingLine = $headingLine + 1
    }
  }

  return [ordered]@{
    found = $true
    reason = ""
    header = $headerColumns
    rows = $rows
    headingLine = $headingLine + 1
  }
}

function Get-FilesCellCount {
  param(
    [Parameter(Mandatory = $true)][string]$Value
  )

  $normalized = ($Value -replace "<br\s*/?>", "," -replace ";", ",").Trim()
  if ([string]::IsNullOrWhiteSpace($normalized)) {
    return 0
  }

  $parts = @($normalized.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
  return $parts.Count
}

function Test-TasksEvidenceSchema {
  param(
    [Parameter(Mandatory = $true)][string]$TasksPath,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$RequiredColumns,
    [Parameter(Mandatory = $true)][string]$RequiredHeading,
    [Parameter(Mandatory = $true)][bool]$RequireNonEmptyRows,
    [Parameter(Mandatory = $true)][int]$MaxFilesPerTaskRow,
    [Parameter(Mandatory = $true)][int]$MaxActionLength
  )

  $table = Get-TaskEvidenceTable -TasksPath $TasksPath -RequiredHeading $RequiredHeading
  if (-not [bool]$table.found) {
    return [ordered]@{
      passed = $false
      reason = $table.reason
      matchedHeader = ""
      rowCount = 0
      violations = @()
    }
  }

  $columns = @($table.header)
  $allRequiredPresent = $true
  foreach ($required in $RequiredColumns) {
    $found = @($columns | Where-Object { $_.Equals($required, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
    if (-not $found) {
      $allRequiredPresent = $false
      break
    }
  }

  if (-not $allRequiredPresent) {
    return [ordered]@{
      passed = $false
      reason = "Task evidence table is missing required columns."
      matchedHeader = ($columns -join ", ")
      rowCount = 0
      violations = @()
    }
  }

  $rows = @($table.rows)
  if ($RequireNonEmptyRows -and $rows.Count -eq 0) {
    return [ordered]@{
      passed = $false
      reason = "Task evidence table must contain at least one data row."
      matchedHeader = ($columns -join ", ")
      rowCount = 0
      violations = @()
    }
  }

  $columnIndex = @{}
  for ($i = 0; $i -lt $columns.Count; $i++) {
    $columnIndex[$columns[$i].ToLowerInvariant()] = $i
  }

  $violations = @()
  for ($rowIndex = 0; $rowIndex -lt $rows.Count; $rowIndex++) {
    $row = @($rows[$rowIndex])

    $filesValue = ""
    $actionValue = ""
    $verifyValue = ""
    $doneValue = ""
    if ($columnIndex.ContainsKey("files") -and $columnIndex["files"] -lt $row.Count) {
      $filesValue = [string]$row[$columnIndex["files"]]
    }
    if ($columnIndex.ContainsKey("action") -and $columnIndex["action"] -lt $row.Count) {
      $actionValue = [string]$row[$columnIndex["action"]]
    }
    if ($columnIndex.ContainsKey("verify") -and $columnIndex["verify"] -lt $row.Count) {
      $verifyValue = [string]$row[$columnIndex["verify"]]
    }
    if ($columnIndex.ContainsKey("done") -and $columnIndex["done"] -lt $row.Count) {
      $doneValue = [string]$row[$columnIndex["done"]]
    }

    if ([string]::IsNullOrWhiteSpace($filesValue) -or [string]::IsNullOrWhiteSpace($actionValue) -or [string]::IsNullOrWhiteSpace($verifyValue) -or [string]::IsNullOrWhiteSpace($doneValue)) {
      $violations += "row#$($rowIndex + 1): Files/Action/Verify/Done must be non-empty."
    }

    $filesCount = Get-FilesCellCount -Value $filesValue
    if ($MaxFilesPerTaskRow -gt 0 -and $filesCount -gt $MaxFilesPerTaskRow) {
      $violations += "row#$($rowIndex + 1): files count $filesCount exceeds max $MaxFilesPerTaskRow."
    }

    if ($MaxActionLength -gt 0 -and $actionValue.Length -gt $MaxActionLength) {
      $violations += "row#$($rowIndex + 1): action length $($actionValue.Length) exceeds max $MaxActionLength."
    }
  }

  return [ordered]@{
    passed = ($violations.Count -eq 0)
    reason = if ($violations.Count -eq 0) { "" } else { "Task evidence row validation failed." }
    matchedHeader = ($columns -join ", ")
    rowCount = $rows.Count
    violations = @($violations)
  }
}

function Test-SessionDisclosureMetadata {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$RequiredMarkers
  )

  if (-not (Test-Path $FilePath)) {
    return [ordered]@{
      passed = $false
      missing = @("file-missing")
    }
  }

  $content = Get-Content -Path $FilePath -Encoding UTF8 -Raw
  $missing = @()
  foreach ($marker in $RequiredMarkers) {
    if ([string]::IsNullOrWhiteSpace($marker)) { continue }
    if (-not [regex]::IsMatch($content, [regex]::Escape($marker), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
      $missing += $marker
    }
  }

  return [ordered]@{
    passed = ($missing.Count -eq 0)
    missing = @($missing)
  }
}

function Test-PathMatchesRegexes {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Regexes
  )

  foreach ($pattern in $Regexes) {
    if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
    $match = [regex]::Match($Path, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($match.Success) {
      return [ordered]@{
        matched = $true
        pattern = $pattern
      }
    }
  }

  return [ordered]@{
    matched = $false
    pattern = ""
  }
}

function Find-SecretMatchesInFile {
  param(
    [Parameter(Mandatory = $true)][string]$FullPath,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$SecretRegexes
  )

  if (-not (Test-Path $FullPath)) {
    return @()
  }

  $item = Get-Item -Path $FullPath
  if ($item.PSIsContainer) {
    return @()
  }

  $content = Get-Content -Path $FullPath -Encoding UTF8 -Raw
  $hits = @()
  foreach ($pattern in $SecretRegexes) {
    if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
    $found = [regex]::Match($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($found.Success) {
      $hits += $pattern
    }
  }
  return @($hits | Select-Object -Unique)
}

function Get-AgentFrontmatterTools {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath
  )

  if (-not (Test-Path $FilePath)) {
    return [ordered]@{
      available = $false
      tools = @()
      reason = "agent file missing"
    }
  }

  $lines = Get-Content -Path $FilePath -Encoding UTF8
  $start = -1
  $end = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq "---") {
      if ($start -lt 0) {
        $start = $i
      } else {
        $end = $i
        break
      }
    }
  }

  if ($start -lt 0 -or $end -lt 0 -or $end -le $start) {
    return [ordered]@{
      available = $false
      tools = @()
      reason = "frontmatter not found"
    }
  }

  $tools = @()
  for ($lineIndex = $start + 1; $lineIndex -lt $end; $lineIndex++) {
    $line = $lines[$lineIndex].Trim()
    if (-not $line.StartsWith("tools:")) { continue }

    $rawValue = $line.Substring("tools:".Length).Trim()
    if ([string]::IsNullOrWhiteSpace($rawValue)) { break }

    $tools = @($rawValue.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
    break
  }

  return [ordered]@{
    available = $true
    tools = @($tools | Select-Object -Unique)
    reason = ""
  }
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

foreach ($override in $runtime.workflowGateOverrides.GetEnumerator()) {
  $config.workflowGate | Add-Member -NotePropertyName $override.Key -NotePropertyValue $override.Value -Force
}

$implementationPrefixes = if ($runtime.implementationPathPrefixes.Count -gt 0) {
  @($runtime.implementationPathPrefixes)
} else {
  @($config.workflowGate.implementationPathPrefixes)
}
$implementationFilesExact = if ($runtime.implementationPathFiles.Count -gt 0) {
  @($runtime.implementationPathFiles)
} else {
  @($config.workflowGate.implementationPathFiles)
}
$ignorePrefixes = @($config.workflowGate.ignorePathPrefixes)
$branchPattern = [string]$config.workflowGate.branchPattern
$ownerWorkspaceRoot = [string]$config.workflowGate.ownerWorkspaceRoot
$requiredTaskEvidenceColumns = @($config.workflowGate.requiredTaskEvidenceColumns)
$requiredTaskEvidenceHeading = [string]$config.workflowGate.requiredTaskEvidenceHeading
$requireNonEmptyTaskEvidenceRows = [bool]$config.workflowGate.requireNonEmptyTaskEvidenceRows
$maxFilesPerTaskRow = 0
$maxActionLength = 0
if ($null -ne $config.workflowGate.taskEvidenceGranularity) {
  $maxFilesPerTaskRow = [int]$config.workflowGate.taskEvidenceGranularity.maxFilesPerTaskRow
  $maxActionLength = [int]$config.workflowGate.taskEvidenceGranularity.maxActionLength
}
$requireSessionDisclosureMetadata = [bool]$config.workflowGate.requireSessionDisclosureMetadata
$requiredSessionDisclosureMarkers = @($config.workflowGate.requiredSessionDisclosureMarkers)
if ($requiredTaskEvidenceColumns.Count -eq 0) {
  $requiredTaskEvidenceColumns = @("Files", "Action", "Verify", "Done")
}
if ([string]::IsNullOrWhiteSpace($requiredTaskEvidenceHeading)) {
  $requiredTaskEvidenceHeading = "Task Evidence"
}
if ($null -eq $config.workflowGate.requireNonEmptyTaskEvidenceRows) {
  $requireNonEmptyTaskEvidenceRows = $true
}
if ($maxFilesPerTaskRow -le 0) {
  $maxFilesPerTaskRow = 4
}
if ($maxActionLength -le 0) {
  $maxActionLength = 220
}
if ($requiredSessionDisclosureMarkers.Count -eq 0) {
  $requiredSessionDisclosureMarkers = @("Memory Sources", "Disclosure Level", "Source IDs")
}
if ([string]::IsNullOrWhiteSpace($ownerWorkspaceRoot)) {
  $ownerWorkspaceRoot = ".trellis/workspace/"
}
$linkedMarker = [string]$config.workflowGate.linkedWorktreeGitDirContains
if ([string]::IsNullOrWhiteSpace($linkedMarker)) {
  $linkedMarker = "/.git/worktrees/"
}

$securityEnabled = ($null -ne $config.securityGate) -and [bool]$config.securityGate.enabled
$securityDenySensitivePaths = $securityEnabled -and [bool]$config.securityGate.denySensitivePathEdits
$securitySensitivePathRegexes = @($config.securityGate.sensitivePathRegexes)
$securitySecretScanEnabled = $securityEnabled -and [bool]$config.securityGate.scanDurableArtifactsForSecrets
$securitySecretScanPrefixes = @($config.securityGate.durableArtifactPathPrefixes)
$securitySecretScanIgnorePrefixes = @($config.securityGate.secretScanIgnorePathPrefixes)
$securitySecretRegexes = @($config.securityGate.secretRegexes)

$orchestratorEnabled = ($null -ne $config.orchestratorGate) -and [bool]$config.orchestratorGate.enabled
$orchestratorDispatchPaths = @($config.orchestratorGate.dispatchAgentPaths)
$orchestratorForbiddenTools = @($config.orchestratorGate.forbiddenTools)
if ($orchestratorForbiddenTools.Count -eq 0) {
  $orchestratorForbiddenTools = @("Write", "Edit", "MultiEdit")
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

    $taskSchema = Test-TasksEvidenceSchema `
      -TasksPath $tasks `
      -RequiredColumns $requiredTaskEvidenceColumns `
      -RequiredHeading $requiredTaskEvidenceHeading `
      -RequireNonEmptyRows $requireNonEmptyTaskEvidenceRows `
      -MaxFilesPerTaskRow $maxFilesPerTaskRow `
      -MaxActionLength $maxActionLength
    Add-Check -Checks $checks `
      -Name "Active change '$($change.Name)' tasks evidence schema is complete" `
      -Severity "fail" `
      -Passed ([bool]$taskSchema.passed) `
      -Details ("required_heading=$requiredTaskEvidenceHeading; required_columns=" + ($requiredTaskEvidenceColumns -join ", ") + "; matched_header=$($taskSchema.matchedHeader); row_count=$($taskSchema.rowCount); reason=$($taskSchema.reason); violations=" + (Join-PathsForDetails -Paths @($taskSchema.violations) -MaxItems 4)) `
      -Remediation "Use heading '$requiredTaskEvidenceHeading' with non-empty task evidence rows and bounded granularity."
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

$branchDelta = Get-BranchDeltaInfo -RepoRoot $repoRoot -BaseRefArg $BaseRef -GateMode $Mode
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
$implementationFilesForMode = @(if ($Mode -eq "ci") { @($branchImplementationFiles) } else { @($workingImplementationFiles) })
$filesForMode = @(if ($Mode -eq "ci") { @($branchDelta.files) } else { @($workingTreeFiles) })
$hasArchiveContextForMode = if ($Mode -eq "ci") { $branchHasArchiveArtifacts } else { $workingHasArchiveArtifacts }
$needsOwnerContext = @($implementationFilesForMode).Count -gt 0
$ownerPrefixForMode = if ([bool]$branchIdentity.valid) { "$ownerWorkspaceRoot$($branchIdentity.owner)/" } else { "$ownerWorkspaceRoot" }
$sessionEvidenceFilesForMode = @($filesForMode | Where-Object {
    $_.StartsWith($ownerPrefixForMode, [System.StringComparison]::OrdinalIgnoreCase)
  })

if ($securityDenySensitivePaths) {
  $sensitivePathHits = @()
  foreach ($file in $implementationFilesForMode) {
    $match = Test-PathMatchesRegexes -Path $file -Regexes $securitySensitivePathRegexes
    if ([bool]$match.matched) {
      $sensitivePathHits += "$file=>pattern:$($match.pattern)"
    }
  }

  Add-Check -Checks $checks `
    -Name "Implementation delta excludes denylisted sensitive paths" `
    -Severity "fail" `
    -Passed (($sensitivePathHits.Count -eq 0) -or (-not $needsOwnerContext)) `
    -Details ("implementation_files=$($implementationFilesForMode.Count); sensitive_hits=" + (Join-PathsForDetails -Paths $sensitivePathHits)) `
    -Remediation "Remove edits to denylisted sensitive files or update policy with explicit reviewed exception."
}

if ($securitySecretScanEnabled) {
  $scanTargets = @()
  foreach ($file in $filesForMode) {
    $shouldInclude = @($securitySecretScanPrefixes | Where-Object {
        $file.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase)
      }).Count -gt 0
    if (-not $shouldInclude) { continue }

    $ignored = @($securitySecretScanIgnorePrefixes | Where-Object {
        $file.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase)
      }).Count -gt 0
    if ($ignored) { continue }

    $scanTargets += $file
  }

  $secretHits = @()
  foreach ($target in $scanTargets) {
    $fullPath = Join-Path $repoRoot ($target -replace "/", "\")
    $hitPatterns = @(Find-SecretMatchesInFile -FullPath $fullPath -SecretRegexes $securitySecretRegexes)
    foreach ($pattern in $hitPatterns) {
      $secretHits += "$target=>pattern:$pattern"
    }
  }

  Add-Check -Checks $checks `
    -Name "Durable artifact secret-pattern scan passes" `
    -Severity "fail" `
    -Passed ($secretHits.Count -eq 0) `
    -Details ("scan_targets=$($scanTargets.Count); secret_hits=" + (Join-PathsForDetails -Paths $secretHits)) `
    -Remediation "Redact credential-like material from durable artifacts and rerun verify."
}

if ($orchestratorEnabled) {
  foreach ($dispatchPath in $orchestratorDispatchPaths) {
    $fullDispatchPath = Join-Path $repoRoot ($dispatchPath -replace "/", "\")
    $dispatchInfo = Get-AgentFrontmatterTools -FilePath $fullDispatchPath
    $forbiddenFound = @()
    foreach ($forbidden in $orchestratorForbiddenTools) {
      $exists = @($dispatchInfo.tools | Where-Object { $_.Equals($forbidden, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
      if ($exists) {
        $forbiddenFound += $forbidden
      }
    }

    Add-Check -Checks $checks `
      -Name "Dispatcher '$dispatchPath' keeps thin orchestrator tool boundary" `
      -Severity "fail" `
      -Passed ([bool]$dispatchInfo.available -and $forbiddenFound.Count -eq 0) `
      -Details ("available=$($dispatchInfo.available); tools=" + (Join-PathsForDetails -Paths @($dispatchInfo.tools)) + "; forbidden_found=" + (Join-PathsForDetails -Paths $forbiddenFound) + "; reason=$($dispatchInfo.reason)") `
      -Remediation "Keep dispatch agent read/route-only; remove forbidden write-capable tools from frontmatter."
  }
}

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

if ($requireSessionDisclosureMetadata) {
  $metadataCandidateFiles = @($sessionEvidenceFilesForMode | Where-Object { $_ -match "/journal-\d+\.md$" })
  $metadataApplicable = $needsOwnerContext -and ($metadataCandidateFiles.Count -gt 0)
  $metadataViolations = @()

  if ($metadataApplicable) {
    foreach ($relativePath in $metadataCandidateFiles) {
      $fullPath = Join-Path $repoRoot ($relativePath -replace "/", "\")
      $disclosureCheck = Test-SessionDisclosureMetadata -FilePath $fullPath -RequiredMarkers $requiredSessionDisclosureMarkers
      if (-not [bool]$disclosureCheck.passed) {
        $metadataViolations += "$relativePath=>missing:" + (($disclosureCheck.missing -join ", "))
      }
    }
  }

  Add-Check -Checks $checks `
    -Name "Owner session evidence includes disclosure metadata" `
    -Severity "fail" `
    -Passed ((-not $metadataApplicable) -or ($metadataViolations.Count -eq 0)) `
    -Details ("required_markers=" + ($requiredSessionDisclosureMarkers -join ", ") + "; files_checked=$($metadataCandidateFiles.Count); violations=" + (Join-PathsForDetails -Paths $metadataViolations)) `
    -Remediation "Add disclosure metadata markers to owner session evidence: $($requiredSessionDisclosureMarkers -join ', ')."
}

$ciFailClosed = ($Mode -eq "ci" -and [bool]$config.workflowGate.ciRequireResolvableBaseRef)
$branchDeltaAvailabilitySeverity = if ($ciFailClosed) { "fail" } else { "warn" }
$branchRuleSeverity = if ($Mode -eq "ci") { "fail" } else { "warn" }
Add-Check -Checks $checks `
  -Name "Branch delta available for governance checks" `
  -Severity $branchDeltaAvailabilitySeverity `
  -Passed ([bool]$branchDelta.available) `
  -Details ("available=$($branchDelta.available); base_ref=$($branchDelta.baseRef); base_sha=$($branchDelta.baseSha); head_sha=$($branchDelta.headSha); merge_base=$($branchDelta.mergeBase); reason=$($branchDelta.reason)") `
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
  runtime = [ordered]@{
    configPath = $runtime.runtimeConfigPath
    adapter = $runtime.adapter
    profile = $runtime.profile
  }
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
  if (-not (Test-Path $metricsOutputDir)) {
    New-Item -ItemType Directory -Path $metricsOutputDir | Out-Null
  }

  $lines = @()
  $lines += "# Workflow Policy Gate"
  $lines += ""
  $lines += "- generated_at_utc: $([DateTimeOffset]::UtcNow.ToString("u"))"
  $lines += "- mode: $Mode"
  $lines += "- outcome: $outcome"
  $lines += "- adapter: $($runtime.adapter)"
  $lines += "- profile: $($runtime.profile)"
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
