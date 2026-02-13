## ADDED Requirements

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
