## ADDED Requirements

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
