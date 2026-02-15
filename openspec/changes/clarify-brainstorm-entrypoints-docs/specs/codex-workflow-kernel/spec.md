## MODIFIED Requirements

### Requirement: One-Command Orchestration Flow
The workflow SHALL provide a one-command orchestration entry that executes end-to-end onboarding/hardening stages with explicit condition controls.

#### Scenario: Contributor runs flow in auto mode
- **WHEN** contributor runs `sbk flow run --decision-mode auto`
- **THEN** runtime resolves key decision nodes deterministically
- **AND** executes the selected stage chain without manual command chaining
- **AND** writes a structured flow report artifact under `.metrics/`

#### Scenario: Install stage is conditionally executed
- **WHEN** contributor does not pass `--with-install`
- **THEN** flow run skips install stage
- **AND** subsequent stages continue based on resolved scenario and options

#### Scenario: Scenario-gated bootstrap stage
- **WHEN** resolved `scenario` is `greenfield`
- **THEN** flow run executes greenfield bootstrap stage
- **AND** when `scenario` is `brownfield` the greenfield stage is not executed

#### Scenario: Beta asset allowance is condition-bound
- **WHEN** contributor runs `sbk flow run --channel beta`
- **THEN** flow run enables beta asset allowance semantics for blueprint/channel assets
- **AND** contributor may also enable beta asset allowance explicitly via `--allow-beta`

#### Scenario: Verify stage is conditionally executed
- **WHEN** contributor passes `--skip-verify`
- **THEN** flow run skips verify-fast stage
- **AND** still emits flow report with executed stage results

#### Scenario: Fleet stages are conditionally executed
- **WHEN** contributor provides `--fleet-roots`
- **THEN** flow run executes fleet collect/report/doctor stages
- **AND** without `--fleet-roots` fleet stages are not executed

#### Scenario: Overwrite behavior is condition-bound
- **WHEN** contributor provides `--force`
- **THEN** flow run enables overwrite behavior for applicable stages
- **AND** blueprint apply may also enter force mode under documented runtime contexts

#### Scenario: Non-git target repository bootstrap
- **WHEN** target repository is not initialized as a git repository
- **THEN** flow run initializes git metadata before intake stages
- **AND** proceeds with orchestration using the initialized repo context

#### Scenario: Auto profile fallback in intake verify
- **WHEN** decision mode is auto and profile is not explicitly provided
- **AND** strict intake verify fails
- **THEN** flow run attempts fallback profiles in bounded order
- **AND** fails only after fallback candidates are exhausted
