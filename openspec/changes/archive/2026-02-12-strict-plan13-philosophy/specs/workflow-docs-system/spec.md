## ADDED Requirements

### Requirement: Security Policy Runbook Coverage

Project docs SHALL include operational guidance for security policy gate behavior.

#### Scenario: Contributor triggers security policy failure

- **WHEN** policy gate reports sensitive path or secret-pattern violation
- **THEN** docs explain failure interpretation, redaction workflow, and remediation
- **AND** docs reference policy-as-code keys used by the gate

### Requirement: Progressive Disclosure Memory Runbook Coverage

Project docs SHALL include staged memory retrieval and audit usage guidance.

#### Scenario: Contributor needs minimal context injection

- **WHEN** they use memory context tooling
- **THEN** docs explain index/detail stages, ID-based retrieval, and audit outputs
- **AND** docs provide Codex skill usage best practices
