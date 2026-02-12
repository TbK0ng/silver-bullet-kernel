## ADDED Requirements

### Requirement: Session Evidence for Implemented Changes

Memory governance SHALL require session evidence artifacts for implementation changes.

#### Scenario: CI validates implementation branch delta

- **WHEN** implementation files are changed in branch delta
- **THEN** policy gate requires corresponding session evidence updates under `.trellis/workspace/`
- **AND** CI fails when session evidence is missing

