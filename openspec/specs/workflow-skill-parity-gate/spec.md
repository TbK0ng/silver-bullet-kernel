# workflow-skill-parity-gate Specification

## Purpose
TBD - created by archiving change sbk-universal-sidecar. Update Purpose after archive.
## Requirements
### Requirement: Skill Distribution Parity Gate
The workflow SHALL fail verification when Codex/Claude skill-command distribution surfaces diverge from parity contract.

#### Scenario: Skill mirrors are incomplete
- **WHEN** `.codex/skills` contains capabilities missing in `.agents/skills` or `.claude/skills`
- **THEN** skill parity gate fails
- **AND** report lists missing items for deterministic remediation

#### Scenario: OpenSpec command namespace remains mapped
- **WHEN** OpenSpec capabilities exist in `.codex/skills`
- **THEN** gate enforces mapped command coverage in `.claude/commands/opsx`
- **AND** verify pipeline blocks merge on mapping drift

#### Scenario: Parity checks pass
- **WHEN** Codex/Agents/Claude capabilities are aligned according to gate rules
- **THEN** gate passes and emits PASS summary report
- **AND** verify and workflow doctor continue to downstream checks

#### Scenario: High-leverage workflow skills remain mirrored
- **WHEN** workflow skills such as `brainstorm` and `improve-ut` are available in Codex distribution
- **THEN** corresponding `.agents/skills`, `.claude/skills`, and `.claude/commands/trellis` artifacts are present
- **AND** parity gate fails with deterministic missing-item output when any surface drifts

