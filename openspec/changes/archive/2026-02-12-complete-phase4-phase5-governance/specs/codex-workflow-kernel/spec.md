## ADDED Requirements

### Requirement: Constitutional Guardrails

The kernel SHALL define and maintain constitution-level rules governing quality, source-of-truth ownership, and recoverability.

#### Scenario: Process change proposal is introduced

- **WHEN** contributors modify workflow behavior
- **THEN** changes are checked against constitutional rules before adoption

### Requirement: Metrics-Backed Improvement Loop

The kernel SHALL support data-driven process tuning.

#### Scenario: Weekly process review

- **WHEN** team reviews workflow performance
- **THEN** they use generated metrics artifacts to identify failures and throughput bottlenecks
- **AND** they update policy or scripts based on measured evidence
