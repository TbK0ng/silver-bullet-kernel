# codex-workflow-kernel Specification

## Purpose
Define the core Codex-first workflow behavior, verification gates, and collaboration invariants for this repository.
## Requirements
### Requirement: Codex-First Runtime Contract

The repository SHALL provide a Codex-first workflow while retaining Claude Code compatibility.

#### Scenario: Codex runtime bootstraps with project policies

- **WHEN** a developer starts work in Codex
- **THEN** Codex can load project skills and instructions from repository-managed files
- **AND** policy files define verify gates and change-control expectations

### Requirement: Deterministic Verification Gates

The repository SHALL provide deterministic verify entry points and enforce them in CI.

#### Scenario: Contributor runs bounded verify/fix loop

- **WHEN** contributor executes `npm run verify:loop`
- **THEN** loop performs bounded verify attempts with diagnostics after failed attempts
- **AND** command exits non-zero when attempts are exhausted

#### Scenario: Contributor runs local verify with virtualenv artifacts present

- **WHEN** `npm run verify:fast` or `npm run verify` is executed in a repo containing `.venv/`
- **THEN** lint scope excludes virtualenv/runtime vendor artifacts
- **AND** verify outcome reflects project files only

### Requirement: Parallel Collaboration Policy

The repository SHALL define a worktree policy for two-person collaboration.

#### Scenario: Two collaborators execute in parallel

- **WHEN** collaborators work on separate changes
- **THEN** each change uses isolated ownership and worktree boundaries
- **AND** spec merges occur through archive flow, not direct concurrent edits to canonical specs

### Requirement: Constitutional Guardrails

The kernel SHALL define and maintain constitution-level rules governing quality, source-of-truth ownership, and recoverability.

#### Scenario: Process change proposal is introduced

- **WHEN** contributors modify workflow behavior
- **THEN** changes are checked against constitutional rules before adoption

### Requirement: Metrics-Backed Improvement Loop

The kernel SHALL support data-driven process tuning.

#### Scenario: Weekly process review

- **WHEN** team reviews workflow performance
- **THEN** they use generated metrics artifacts to identify failures and throughput bottlenecks
- **AND** they update policy or scripts based on measured evidence

### Requirement: Enforced Change-Control Gate

The kernel SHALL block verification when implementation changes are not traceable to OpenSpec change artifacts.

#### Scenario: Implementation files change without OpenSpec change mapping

- **WHEN** verify commands execute on non-trivial implementation changes
- **THEN** policy gate fails if no corresponding change artifacts are present
- **AND** remediation guidance points contributor to create or complete a change package

### Requirement: Active Change Artifact Completeness

The kernel SHALL require complete active-change artifacts before verify succeeds.

#### Scenario: Active change tasks evidence table is decorative only

- **WHEN** policy gate validates active change artifacts
- **THEN** `tasks.md` must contain a canonical `Task Evidence` table with required
  columns (`Files`, `Action`, `Verify`, `Done`)
- **AND** the table must include at least one non-empty data row
- **AND** verify fails when schema or row-level evidence is missing

### Requirement: CI Branch Governance Fail-Closed

The kernel SHALL fail CI policy checks when branch-delta governance context is unavailable or degenerate.

#### Scenario: CI base ref resolves to current HEAD

- **WHEN** `verify:ci` runs policy gate in PR governance flow
- **AND** configured base ref resolves to the same commit as `HEAD`
- **THEN** policy gate fails as invalid branch-delta context
- **AND** remediation instructs operators to provide an event-correct base ref

### Requirement: Owner/Change Branch Mapping Enforcement

The kernel SHALL enforce branch naming and ownership mapping for implementation changes.

#### Scenario: Implementation branch name does not match required pattern

- **WHEN** implementation edits are present
- **THEN** policy gate validates branch pattern with owner and change identifiers
- **AND** fails when pattern or active-change mapping is invalid

### Requirement: Linked Worktree Requirement for Local Implementation

The kernel SHALL enforce linked worktree usage for local implementation changes.

#### Scenario: Contributor edits implementation on main worktree

- **WHEN** local policy gate detects implementation edits
- **THEN** it fails if current git directory is not a linked worktree
- **AND** remediation points to creating/using per-change worktree

### Requirement: Tool-Deterministic Refactor Path

The kernel SHALL provide a semantic refactor path for TypeScript symbol rename operations.

#### Scenario: Contributor performs symbol rename

- **WHEN** contributor executes semantic rename command with file/line/column and new symbol name
- **THEN** rename is resolved by TypeScript compiler APIs (not plain text replace)
- **AND** command fails with explicit error when symbol resolution is invalid

### Requirement: Task Granularity Policy Enforcement

The kernel SHALL enforce bounded task granularity for active-change evidence rows.

#### Scenario: Task evidence row is oversized

- **WHEN** policy gate parses active change task-evidence rows
- **THEN** each row is checked against configured bounds (files count/action length)
- **AND** verify fails with remediation when bounds are exceeded

### Requirement: Orchestrator Boundary Governance

The kernel SHALL enforce thin orchestrator boundaries as policy-as-code.

#### Scenario: Dispatcher agent exposes write-capable tools

- **WHEN** policy gate validates orchestrator contracts
- **THEN** dispatcher toolset is checked against forbidden tool rules
- **AND** verify fails if forbidden tools are present

### Requirement: Indicator Gate Entry Point Consistency

The kernel SHALL expose a stable indicator-gate command contract for operators.

#### Scenario: Contributor executes workflow indicator gate command

- **WHEN** contributor runs `npm run workflow:gate`
- **THEN** command executes indicator-threshold checks (not policy gate checks)
- **AND** docs and npm script mapping stay consistent with this behavior

### Requirement: Safe Delta Spec Migration
The kernel SHALL merge OpenSpec delta requirements into canonical capability specs by default when contributors run `sbk migrate-specs --apply`.

#### Scenario: Delta adds or modifies requirement content
- **WHEN** contributor applies migrate-specs for a change with `ADDED` or `MODIFIED` requirement deltas
- **THEN** canonical specs preserve untouched requirements and scenarios
- **AND** only matching requirement/scenario blocks are updated or appended

#### Scenario: Delta references missing requirement for modification/removal
- **WHEN** contributor applies migrate-specs and delta contains `MODIFIED` or `REMOVED` entries not present in canonical spec
- **THEN** command fails non-zero with actionable error
- **AND** canonical files remain unchanged for that capability

#### Scenario: Contributor explicitly requests destructive overwrite
- **WHEN** contributor runs `sbk migrate-specs --apply --unsafe-overwrite`
- **THEN** migration writes delta file content directly to canonical target path
- **AND** command output marks overwrite mode as explicit unsafe behavior

### Requirement: Greenfield Bootstrap Entry Command
The kernel SHALL provide a dedicated greenfield bootstrap command for repository initialization.

#### Scenario: Contributor starts a new repository with SBK
- **WHEN** contributor runs `sbk greenfield --adapter <name>`
- **THEN** command generates project-level planning artifacts required for workflow execution
- **AND** command returns non-zero when adapter input is invalid

### Requirement: Project-Level Artifact Scaffolding
The kernel SHALL scaffold project-level planning artifacts for zero-to-one workflows.

#### Scenario: Artifact scaffold executes in empty repository
- **WHEN** greenfield bootstrap runs in a repository without planning artifacts
- **THEN** it creates `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md`, and `CONTEXT.md`
- **AND** it creates `.planning/research/.gitkeep` for research outputs

#### Scenario: Artifact scaffold reruns without force
- **WHEN** files already exist and contributor reruns command without `--force`
- **THEN** existing files are preserved
- **AND** command reports skipped targets

### Requirement: Adapter-Aware Starter Stub Scaffolding
The kernel SHALL generate adapter-aligned starter stub files for supported ecosystems.

#### Scenario: Node adapter scaffold
- **WHEN** contributor selects `--adapter node-ts`
- **THEN** command creates minimal Node/TypeScript starter files required for adapter detection
- **AND** generated output includes placeholder verification scripts that can be replaced by project-specific commands

#### Scenario: Non-Node adapter scaffold
- **WHEN** contributor selects `python`, `go`, `java`, or `rust`
- **THEN** command creates minimal starter files aligned with adapter detection markers
- **AND** command updates `sbk.config.json` with selected adapter unless already set and `--force` is not used

### Requirement: Kernel Install and Upgrade Entry Commands
The kernel SHALL provide explicit install and upgrade commands for target repositories.

#### Scenario: Contributor installs SBK into external repository
- **WHEN** contributor runs `sbk install --target-repo-root <path> --preset <minimal|full>`
- **THEN** command copies kernel files according to preset scope
- **AND** command reports created/skipped/overwritten counts

#### Scenario: Contributor upgrades existing SBK installation
- **WHEN** contributor runs `sbk upgrade --target-repo-root <path> --preset <minimal|full>`
- **THEN** installer runs in overwrite mode
- **AND** command reports overwritten file count explicitly

### Requirement: Preset-Based Install Surface
The kernel SHALL support deterministic preset scopes for distribution.

#### Scenario: Minimal preset install
- **WHEN** contributor selects `minimal` preset
- **THEN** target receives strict governance core files required for verify/policy/doctor entrypoints
- **AND** volatile runtime artifacts are excluded

#### Scenario: Full preset install
- **WHEN** contributor selects `full` preset
- **THEN** target receives extended runtime assets, configs, docs, and workflow specs
- **AND** install still excludes runtime state directories

### Requirement: Non-Destructive Script Injection
The kernel SHALL inject package scripts additively when target package metadata exists.

#### Scenario: Target repository contains package.json
- **WHEN** installer runs against target with package metadata
- **THEN** missing SBK scripts are added only when corresponding files exist
- **AND** existing script definitions are preserved unless overwrite mode updates file content only

### Requirement: Runtime Contract Includes `sbk` Entry Command
The repository SHALL provide a canonical `sbk` command as the preferred workflow entrypoint.

#### Scenario: Team bootstraps a new project
- **WHEN** contributors configure SBK in a new repository
- **THEN** they can execute core lifecycle actions via `sbk` command aliases without invoking individual scripts manually
- **AND** command behavior remains traceable to policy-as-code configuration

### Requirement: Verify/Policy Uses Target-Aware Adapter Context
The kernel SHALL resolve implementation scope and verify steps from adapter/runtime configuration.

#### Scenario: Supported ecosystem uses adapter command matrix
- **WHEN** verify commands execute under an active adapter
- **THEN** the command matrix for `fast`/`full`/`ci` is read from adapter config
- **AND** policy gate uses adapter-provided implementation path matching rules

### Requirement: Runtime Exposes Platform Capability Matrix
The kernel SHALL publish platform capability differences through `sbk capabilities`.

#### Scenario: Contributor checks Claude/Codex parity status
- **WHEN** contributor runs `sbk capabilities`
- **THEN** command prints selected platform and capability matrix sourced from config
- **AND** manual-mode platforms include explicit resume/continue hints

### Requirement: Codex Multi-Agent Supports Manual Execution Mode
The kernel SHALL support `--platform codex` in multi-agent start/status flows without requiring CLI session controls.

#### Scenario: Start codex worktree task
- **WHEN** contributor starts multi-agent task with `--platform codex`
- **THEN** workflow creates worktree, task context, and registry record
- **AND** it does not fail due to missing CLI session-id/resume features

### Requirement: `sbk` Entry Covers Advanced Workflow Operations
The kernel SHALL expose Trellis advanced workflows through `sbk` subcommands without requiring contributors to discover raw script paths.

#### Scenario: Contributor invokes advanced workflow from `sbk`
- **WHEN** contributor runs `sbk explore`, `sbk improve-ut`, `sbk migrate-specs`, or `sbk parallel`
- **THEN** dispatcher routes to corresponding workflow script/behavior with argument forwarding
- **AND** command exits non-zero when delegated operation fails
- **AND** help text documents the routed workflow contract

### Requirement: One-Command Orchestration Flow
The workflow SHALL provide a one-command orchestration entry that executes end-to-end onboarding/hardening stages.

#### Scenario: Contributor runs flow in auto mode
- **WHEN** contributor runs `sbk flow run --decision-mode auto`
- **THEN** runtime resolves key decision nodes deterministically
- **AND** executes the selected stage chain without manual command chaining
- **AND** writes a structured flow report artifact under `.metrics/`

### Requirement: Decision-Node Control Mode
The orchestration flow SHALL support deterministic auto decisions and interactive operator decisions.

#### Scenario: Contributor runs flow in ask mode
- **WHEN** contributor runs `sbk flow run --decision-mode ask`
- **THEN** unresolved key nodes are presented to operator prompts
- **AND** selected decisions are captured in flow report output
- **AND** flow continues with chosen values

### Requirement: Strict Intake Readiness Default
Strict profile governance SHALL enforce intake readiness artifacts by default.

#### Scenario: Strict verify runs without intake readiness
- **WHEN** strict profile policy gate executes and readiness artifact is missing
- **THEN** policy gate fails with remediation
- **AND** contributor is instructed to run intake analyze/plan/verify stages

