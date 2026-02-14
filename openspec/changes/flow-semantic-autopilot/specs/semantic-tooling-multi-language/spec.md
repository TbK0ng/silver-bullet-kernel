## ADDED Requirements

### Requirement: Enabled Semantic Reference Mapping
The workflow SHALL expose semantic reference-map operations for supported adapters.

#### Scenario: Contributor requests reference map
- **WHEN** contributor runs `sbk semantic reference-map --file <path> --line <n> --column <n>`
- **THEN** command returns deterministic symbol reference mapping output
- **AND** operation writes report/audit artifacts under `.metrics/`

### Requirement: Enabled Safe Delete Candidate Analysis
The workflow SHALL expose semantic safe-delete candidate analysis for supported adapters.

#### Scenario: Contributor requests safe-delete candidate analysis
- **WHEN** contributor runs `sbk semantic safe-delete-candidates --file <path> --line <n> --column <n>`
- **THEN** command returns candidate safety classification with evidence
- **AND** output includes deterministic remediation guidance

### Requirement: Deterministic Non-TS Semantic Backend
The workflow SHALL provide deterministic semantic operation support for Go, Java, and Rust adapters.

#### Scenario: Contributor runs semantic rename on Rust adapter
- **WHEN** contributor runs semantic rename under `rust` adapter
- **THEN** runtime executes deterministic backend contract (not placeholder fail-closed)
- **AND** operation outputs structured touched-files/touched-locations summary