# workflow-security-policy Specification

## Purpose
TBD - created by archiving change strict-plan13-philosophy. Update Purpose after archive.
## Requirements
### Requirement: Sensitive Path Denylist Enforcement

The workflow SHALL enforce denylisted sensitive paths as policy-as-code.

#### Scenario: Implementation delta touches a denylisted path

- **WHEN** policy gate evaluates implementation files
- **THEN** changed paths are matched against configured sensitive-path rules
- **AND** verify fails on denylisted matches

### Requirement: Durable Artifact Secret Scan

The workflow SHALL scan durable artifacts for secret-like patterns.

#### Scenario: Session notes include leaked credential token

- **WHEN** policy gate scans changed durable artifacts
- **THEN** configurable secret regex patterns are evaluated
- **AND** verify fails with file-level remediation details on match

