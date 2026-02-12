# session-recovery-proof Specification

## Purpose
Define the minimum committed artifacts required to prove sessions are recoverable across runs.
## Requirements
### Requirement: Recoverable Session Sample

The repository SHALL include a committed sample workspace journal proving the recovery format.

#### Scenario: New collaborator inspects session recovery format

- **WHEN** they open the sample workspace directory
- **THEN** they can see a valid index and journal with summary, changes, verification, and next steps

### Requirement: Session Close Evidence

Session governance SHALL require explicit close-out evidence.

#### Scenario: Significant work session ends

- **WHEN** a contributor closes a session
- **THEN** they record recovery-ready notes and verification evidence
- **AND** stable learnings are promoted to guides or docs
