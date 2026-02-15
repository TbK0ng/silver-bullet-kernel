## Why

Current SBK docs describe many commands correctly, but trigger semantics are still inconsistent in key places:
- Some command runbooks imply stages are always chained when they are actually conditional.
- Some exploration/session actions that require explicit invocation are not clearly labeled as explicit.
- Some prompt-oriented docs blur the line between "AI can execute this for you" and "the command implicitly does this."

This creates operator confusion and avoidable execution mistakes.

## What Changes

- Align docs with runtime truth for `sbk flow run` stage triggering:
  - `install` is conditional (`--with-install`)
  - `verify fast` is conditional (`--skip-verify`)
  - `fleet` stages are conditional (`--fleet-roots`)
  - `greenfield` stage is conditional on `scenario`
  - beta asset allowance behavior is condition-bound (`--channel beta` or explicit `--allow-beta`)
  - overwrite behavior is condition-bound (`--force`, and specific blueprint force contexts)
  - non-git target bootstrap behavior is documented (`git init`)
  - intake verify fallback behavior in auto mode is documented
- Clarify explicit-trigger commands:
  - `/trellis:start`
  - `/trellis:record-session` / `sbk record-session`
  - `sbk explore`
  - `sbk new-change`
  - high-risk explicit switches (`flow --force`, `flow --allow-beta`, `migrate-specs --unsafe-overwrite`)
- Correct docs where implicit behavior is overstated or explicit behavior is omitted.
- Add wording that distinguishes:
  - command semantics
  - AI delegation semantics (AI auto-execution of explicit steps)
- Standardize operator examples to include both:
  - generic `sbk ...` form
  - repo-local equivalent `npm run sbk -- ...` where helpful

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `codex-workflow-kernel`: clarify one-command orchestration stage conditions and fallback behavior as part of runtime contract.
- `workflow-docs-system`: require docs to explicitly represent trigger semantics (explicit vs conditional implicit) and avoid AI/command semantic conflation.

## Impact

- Affected docs:
  - `docs/README.md`
  - `docs/01-从Trellis到Silver-Bullet-Kernel的扩展全景.md`
  - `docs/02-功能手册-命令原理与产物.md`
  - `docs/05-命令与产物速查表.md`
  - `docs/06-多项目类型接入与配置指南.md`
  - `docs/07-命令触发语义对照表.md`
  - `docs/practice/00-导航与阅读地图.md`
  - `docs/practice/01-一页上手-从引入到首轮可运行.md`
  - `docs/practice/02-场景实战-绿地项目.md`
  - `docs/practice/03-场景实战-存量项目接管.md`
  - `docs/practice/04-能力手册-命令分层与组合策略.md`
  - `docs/practice/05-相近功能辨析-怎么选与为什么.md`
  - `docs/practice/06-提示词手册-Codex主线.md`
  - `docs/practice/08-附录-平台差异与Beta能力.md`
  - `docs/practice/09-代码库架构深潜.md`
- Affected OpenSpec artifacts:
  - `openspec/changes/clarify-brainstorm-entrypoints-docs/design.md`
  - `openspec/changes/clarify-brainstorm-entrypoints-docs/specs/codex-workflow-kernel/spec.md`
  - `openspec/changes/clarify-brainstorm-entrypoints-docs/specs/workflow-docs-system/spec.md`
  - `openspec/changes/clarify-brainstorm-entrypoints-docs/tasks.md`
- Minor CLI help-text alignment:
  - `scripts/sbk.ps1` flow usage string now includes `--allow-beta` and `--force` to match `scripts/sbk-flow.ps1`.
- No flow orchestration behavior/path changes.
