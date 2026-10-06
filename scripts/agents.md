## Agents — scripts

Purpose
- Agent operating notes for the `scripts/` directory. Documents conventions and who/what consumes these scripts.

Consumers
- Humans: developers and reviewers.
- Automation: CI jobs and agent automation that perform validation, planning, or connectivity checks.

Conventions
- Scripts are POSIX/bash oriented. Prefer `set -euo pipefail` and clear exit codes.
- Keep scripts idempotent and side-effect free where practical.
- Never embed secrets, absolute local credential paths, or service-account JSON files. Use environment variables or a secret manager.

Operation
- Use `./scripts/validate.sh` for repository checks, `./scripts/plan.sh` for plan wrappers, and `./scripts/test-connectivity.sh` for network checks.
- Agents modifying scripts must follow the rules in `AGENTS.md` (traceability, minimal changes, and progressive disclosure).

Links
- Agent rules: `AGENTS.md`
- Repo runbooks: `docs/operations/deployment-and-validation.md`

- Progressive Disclosure (skill): [`Agents/skills/Progressive-Disclosure/SKILL.md`](Agents/skills/Progressive-Disclosure/SKILL.md) — Use the repository's Progressive Disclosure skill. Applies the 4-tier disclosure model, TOML front-matter, breadcrumbs, and AI retrieval hints to keep documentation concise and reviewer-friendly. See the skill for templates and quality gates.
