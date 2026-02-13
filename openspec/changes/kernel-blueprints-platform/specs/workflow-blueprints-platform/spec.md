## ADDED Requirements

### Requirement: Versioned Blueprint Packs
The workflow SHALL support versioned blueprint packs for greenfield baseline generation.

#### Scenario: Contributor lists available blueprints
- **WHEN** contributor runs `sbk blueprint list`
- **THEN** command outputs pack names, versions, and supported adapters
- **AND** output includes stability channel (`stable` or `beta`)

### Requirement: Blueprint Apply Generates Production Baseline
Blueprint apply SHALL generate a policy-aligned baseline beyond MVP scaffolding.

#### Scenario: Apply API-service blueprint
- **WHEN** contributor runs `sbk blueprint apply --name api-service --target-repo-root <path>`
- **THEN** target repo receives CI workflow, verify command map, security/runbook stubs, and architecture artifact templates
- **AND** command fails non-zero if target path validation fails

### Requirement: Blueprint Verify Enforces Baseline Coherence
Blueprint verify SHALL detect incomplete or inconsistent generated baselines.

#### Scenario: Generated baseline missing required artifact
- **WHEN** contributor runs `sbk blueprint verify --target-repo-root <path>`
- **THEN** command reports missing required artifacts with remediation guidance
- **AND** exits non-zero until baseline is complete
