# semantic-tooling-multi-language Specification

## Purpose
TBD - created by archiving change adapter-sdk-semantic-tooling. Update Purpose after archive.
## Requirements
### Requirement: Multi-Language Semantic Operation Contract
The workflow SHALL expose deterministic semantic operations across supported language ecosystems.

#### Scenario: Contributor requests semantic rename on non-TypeScript adapter
- **WHEN** contributor runs semantic rename under Python, Go, Java, or Rust adapter
- **THEN** operation routes through language-appropriate semantic backend
- **AND** command reports affected symbols/files in structured output

### Requirement: Fail-Closed Semantic Safety
Semantic operations SHALL fail closed when backend capability is unavailable.

#### Scenario: Backend cannot guarantee deterministic result
- **WHEN** semantic operation capability is missing or unstable for active adapter
- **THEN** command exits non-zero with explicit reason
- **AND** output provides safe fallback guidance

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

