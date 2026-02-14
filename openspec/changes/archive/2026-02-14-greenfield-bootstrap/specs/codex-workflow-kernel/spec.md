## ADDED Requirements

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
