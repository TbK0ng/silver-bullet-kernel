# memory-governance-policy Specification

## Purpose
Define enforceable memory source, retention, and redaction rules for workflow artifacts.
## Requirements
### Requirement: Memory Source Governance

The workflow SHALL explicitly define approved memory sources and their responsibilities.

#### Scenario: Agent determines what context to inject

- **WHEN** an agent starts or resumes work
- **THEN** it references approved sources (`.trellis/workspace/`, `openspec/`, `xxx_docs/`)
- **AND** it avoids ad-hoc undocumented context stores

### Requirement: Retention and Redaction Policy

The workflow SHALL enforce retention boundaries and sensitive-data redaction.

#### Scenario: Session summary contains secret-like content

- **WHEN** a session record is about to be persisted
- **THEN** credentials and tokens are redacted
- **AND** durable records avoid storing secrets

### Requirement: Session Evidence for Implemented Changes

Memory governance SHALL require session evidence artifacts for implementation changes.

#### Scenario: CI validates implementation branch delta

- **WHEN** implementation files are changed in branch delta
- **THEN** policy gate requires corresponding session evidence updates under `.trellis/workspace/`
- **AND** CI fails when session evidence is missing

