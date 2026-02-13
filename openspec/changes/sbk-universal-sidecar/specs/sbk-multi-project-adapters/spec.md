## ADDED Requirements

### Requirement: Adapter-Driven Project Targeting
The kernel SHALL provide adapter-based targeting so workflow policy and verification can run against different project ecosystems without changing script code.

#### Scenario: Auto-detect adapter for a supported project
- **WHEN** `sbk` runtime starts with adapter mode set to `auto`
- **THEN** it identifies one of the built-in adapters (Node/TS, Python, Go, Java, Rust) using repository marker files
- **AND** it resolves implementation path rules and verify command matrix from the detected adapter manifest

#### Scenario: Explicit adapter override
- **WHEN** contributor sets an explicit adapter in runtime config
- **THEN** runtime uses that adapter even if auto-detect would choose another
- **AND** verify/policy scripts consume the overridden adapter manifest deterministically

### Requirement: Unified `sbk` Command Dispatch
The kernel SHALL expose a single `sbk` command contract for core workflow actions.

#### Scenario: Contributor runs `sbk verify:fast`
- **WHEN** contributor invokes `sbk verify:fast`
- **THEN** runtime executes policy gate and fast verify commands resolved by active adapter/profile
- **AND** writes telemetry/report artifacts to configured metrics paths

#### Scenario: Contributor runs workflow operations through `sbk`
- **WHEN** contributor invokes `sbk` subcommands for doctor/policy/change/session
- **THEN** dispatcher routes to existing scripts with parameter forwarding
- **AND** exits non-zero when the delegated operation fails

#### Scenario: Contributor runs multi-agent orchestration through `sbk parallel`
- **WHEN** contributor invokes `sbk parallel <plan|start|status|cleanup> ...`
- **THEN** dispatcher executes `.trellis/scripts/multi_agent/*.py` with forwarded arguments
- **AND** codex platform path remains manual-mode compatible while claude path remains session-capable

### Requirement: Python Runtime Dispatch Fallback
The kernel SHALL resolve Python command execution for script delegation across heterogeneous project environments.

#### Scenario: Machine lacks `python` command
- **WHEN** `sbk` needs to execute a Python workflow script and `python` is unavailable
- **THEN** runtime attempts supported fallbacks (`py -3`, then `uv run python`)
- **AND** command fails with a clear actionable error if no Python runtime can be resolved

#### Scenario: Contributor inspects platform capability matrix
- **WHEN** contributor invokes `sbk capabilities`
- **THEN** dispatcher prints matrix fields for each supported platform
- **AND** selected platform resolution follows runtime detection/override rules
