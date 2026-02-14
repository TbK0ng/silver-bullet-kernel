param(
  [ValidateSet("node-ts", "python", "go", "java", "rust")][string]$Adapter = "node-ts",
  [string]$ProjectName = "",
  [ValidateSet("backend", "frontend", "fullstack")][string]$ProjectType = "fullstack",
  [string]$TargetRepoRoot = ".",
  [switch]$NoLanguageStubs,
  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$targetRoot = if ([System.IO.Path]::IsPathRooted($TargetRepoRoot)) {
  $TargetRepoRoot
} else {
  Join-Path $repoRoot ($TargetRepoRoot -replace "/", "\")
}
if (-not (Test-Path $targetRoot)) {
  New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
}
$targetRoot = (Resolve-Path $targetRoot).Path

if ([string]::IsNullOrWhiteSpace($ProjectName)) {
  $ProjectName = Split-Path $targetRoot -Leaf
}

$projectSlug = ($ProjectName.ToLowerInvariant() -replace "[^a-z0-9-]", "-").Trim("-")
if ([string]::IsNullOrWhiteSpace($projectSlug)) {
  $projectSlug = "greenfield-app"
}

$adapterConfigPath = Join-Path $repoRoot ("config\\adapters\\{0}.json" -f $Adapter)
if (-not (Test-Path $adapterConfigPath)) {
  $availableAdapters = Get-ChildItem (Join-Path $repoRoot "config\\adapters") -Filter "*.json" |
    ForEach-Object { $_.BaseName } |
    Sort-Object
  throw ("unsupported adapter '{0}'. available: {1}" -f $Adapter, ($availableAdapters -join ", "))
}

$stats = [ordered]@{
  created = 0
  updated = 0
  skipped = 0
}

function Write-ScaffoldFile {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content,
    [Parameter(Mandatory = $true)][bool]$Overwrite,
    [Parameter(Mandatory = $true)][hashtable]$Summary
  )

  $normalizedPath = $RelativePath -replace "/", "\"
  $absolutePath = Join-Path $Root $normalizedPath
  $parentDir = Split-Path $absolutePath -Parent
  if (-not (Test-Path $parentDir)) {
    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
  }

  if (Test-Path $absolutePath) {
    if (-not $Overwrite) {
      $Summary["skipped"]++
      return
    }
    Set-Content -Path $absolutePath -Value $Content -Encoding UTF8
    $Summary["updated"]++
    return
  }

  Set-Content -Path $absolutePath -Value $Content -Encoding UTF8
  $Summary["created"]++
}

function Get-ProjectArtifactTemplates {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Type
  )

  $templates = [ordered]@{}
  $templates["PROJECT.md"] = @"
# PROJECT

## Name
$Name

## Type
$Type

## Problem Statement
- Describe the core user problem this project solves.

## Success Criteria
- Define measurable outcomes for v1.

## Constraints
- List runtime, compliance, and platform constraints.

## Out of Scope
- Capture what this project will not solve in v1.
"@

  $templates["REQUIREMENTS.md"] = @"
# REQUIREMENTS

## Functional (v1)
- [ ] Requirement 1
- [ ] Requirement 2

## Non-Functional
- [ ] Reliability expectations
- [ ] Performance expectations
- [ ] Security expectations

## v2 Candidates
- Future enhancements not required for v1.
"@

  $templates["ROADMAP.md"] = @"
# ROADMAP

## Phase 0: Foundation
- Define architecture and project conventions.

## Phase 1: Core Capability
- Deliver minimum usable workflow.

## Phase 2: Hardening
- Add tests, observability, and policy gates.

## Phase 3: Expansion
- Add optional scenarios and integrations.
"@

  $templates["STATE.md"] = @"
# STATE

## Current Focus
- Track the active milestone and owner.

## Next Actions
1. Fill requirements and acceptance criteria.
2. Create OpenSpec change for first implementation.
3. Run verify fast loop for each completed task.

## Risks
- Record active risks and mitigations.

## Last Updated
- YYYY-MM-DD
"@

  $templates["CONTEXT.md"] = @"
# CONTEXT

## Product Preferences
- Capture UX, API, and architecture preferences.

## Decision Log
- Date | Decision | Rationale

## Open Questions
- Pending clarifications before implementation.

## References
- Related docs and source links.
"@

  $templates[".planning/research/.gitkeep"] = ""
  return $templates
}

function Get-LanguageStubTemplates {
  param(
    [Parameter(Mandatory = $true)][string]$SelectedAdapter,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Slug
  )

  $templates = [ordered]@{}

  switch ($SelectedAdapter) {
    "node-ts" {
      $templates["package.json"] = @"
{
  "name": "$Slug",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "lint": "node -e \"process.exit(0)\"",
    "typecheck": "node -e \"process.exit(0)\"",
    "test": "node -e \"process.exit(0)\"",
    "build": "node -e \"process.exit(0)\""
  }
}
"@
      $templates["src/index.ts"] = @"
export function bootstrap(): string {
  return "$Name";
}
"@
      $templates["tests/smoke.test.ts"] = @"
import { describe, expect, it } from "vitest";
import { bootstrap } from "../src/index";

describe("bootstrap", () => {
  it("returns project name", () => {
    expect(bootstrap()).toBe("$Name");
  });
});
"@
    }
    "python" {
      $templates["pyproject.toml"] = @"
[project]
name = "$Slug"
version = "0.1.0"
requires-python = ">=3.11"

[tool.pytest.ini_options]
testpaths = ["tests"]
"@
      $templates["src/__init__.py"] = @"
def bootstrap() -> str:
    return "$Name"
"@
      $templates["tests/test_smoke.py"] = @"
from src import bootstrap


def test_bootstrap():
    assert bootstrap() == "$Name"
"@
    }
    "go" {
      $templates["go.mod"] = @"
module example.com/$Slug

go 1.22
"@
      $templates["cmd/app/main.go"] = @"
package main

import "fmt"

func main() {
	fmt.Println("$Name")
}
"@
    }
    "java" {
      $templates["pom.xml"] = @"
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>$Slug</artifactId>
  <version>0.1.0</version>
  <properties>
    <maven.compiler.source>17</maven.compiler.source>
    <maven.compiler.target>17</maven.compiler.target>
  </properties>
</project>
"@
      $templates["src/main/java/App.java"] = @"
public class App {
  public static String bootstrap() {
    return "$Name";
  }
}
"@
    }
    "rust" {
      $templates["Cargo.toml"] = @"
[package]
name = "$Slug"
version = "0.1.0"
edition = "2021"
"@
      $templates["src/main.rs"] = @"
fn main() {
    println!("$Name");
}
"@
    }
    default {
      throw "unsupported adapter: $SelectedAdapter"
    }
  }

  return $templates
}

function Set-JsonProperty {
  param(
    [Parameter(Mandatory = $true)][psobject]$Object,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)]$Value
  )

  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) {
    $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
  } else {
    $property.Value = $Value
  }
}

function Update-SbkConfig {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$SelectedAdapter,
    [Parameter(Mandatory = $true)][bool]$Overwrite,
    [Parameter(Mandatory = $true)][hashtable]$Summary
  )

  $configPath = Join-Path $Root "sbk.config.json"
  $config = $null

  if (Test-Path $configPath) {
    $raw = Get-Content -Path $configPath -Encoding UTF8 -Raw
    $config = $raw | ConvertFrom-Json
    $existingAdapter = ""
    $existingProperty = $config.PSObject.Properties["adapter"]
    if ($null -ne $existingProperty -and -not [string]::IsNullOrWhiteSpace([string]$existingProperty.Value)) {
      $existingAdapter = [string]$existingProperty.Value
    }

    if (-not $Overwrite -and $existingAdapter -ne "" -and $existingAdapter -ne "auto") {
      $Summary["skipped"]++
      return
    }
  } else {
    $config = [pscustomobject]@{
      version = 1
      adapter = $SelectedAdapter
      profile = "strict"
      targetRepoRoot = "."
      adaptersDir = "config/adapters"
    }
    $configJson = $config | ConvertTo-Json -Depth 100
    Set-Content -Path $configPath -Value $configJson -Encoding UTF8
    $Summary["created"]++
    return
  }

  Set-JsonProperty -Object $config -Name "adapter" -Value $SelectedAdapter
  $updatedJson = $config | ConvertTo-Json -Depth 100
  Set-Content -Path $configPath -Value $updatedJson -Encoding UTF8
  $Summary["updated"]++
}

$projectArtifacts = Get-ProjectArtifactTemplates -Name $ProjectName -Type $ProjectType
foreach ($relativePath in $projectArtifacts.Keys) {
  Write-ScaffoldFile `
    -Root $targetRoot `
    -RelativePath $relativePath `
    -Content ([string]$projectArtifacts[$relativePath]) `
    -Overwrite ([bool]$Force) `
    -Summary $stats
}

if (-not $NoLanguageStubs) {
  $languageTemplates = Get-LanguageStubTemplates -SelectedAdapter $Adapter -Name $ProjectName -Slug $projectSlug
  foreach ($relativePath in $languageTemplates.Keys) {
    Write-ScaffoldFile `
      -Root $targetRoot `
      -RelativePath $relativePath `
      -Content ([string]$languageTemplates[$relativePath]) `
      -Overwrite ([bool]$Force) `
      -Summary $stats
  }
}

Update-SbkConfig -Root $targetRoot -SelectedAdapter $Adapter -Overwrite ([bool]$Force) -Summary $stats

Write-Host ("[greenfield] adapter={0} project_name={1} project_type={2}" -f $Adapter, $ProjectName, $ProjectType)
Write-Host ("[greenfield] target_repo_root={0}" -f $targetRoot)
Write-Host ("[greenfield] language_stubs={0}" -f (-not $NoLanguageStubs))
Write-Host ("[greenfield] created={0} updated={1} skipped={2}" -f $stats.created, $stats.updated, $stats.skipped)
