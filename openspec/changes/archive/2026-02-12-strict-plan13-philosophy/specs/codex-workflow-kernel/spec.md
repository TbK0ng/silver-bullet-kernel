## MODIFIED Requirements

### Requirement: Active Change Artifact Completeness

The kernel SHALL require complete active-change artifacts before verify succeeds.

#### Scenario: Active change tasks evidence table is decorative only

- **WHEN** policy gate validates active change artifacts
- **THEN** `tasks.md` must contain a canonical `Task Evidence` table with required
  columns (`Files`, `Action`, `Verify`, `Done`)
- **AND** the table must include at least one non-empty data row
- **AND** verify fails when schema or row-level evidence is missing

## ADDED Requirements

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
