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

