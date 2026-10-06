## Scripts

Purpose
- Helper scripts for repository validation, Terraform plan wrappers, and connectivity checks used by developers and CI.

Prerequisites
- bash (POSIX-compatible shell)
- terraform (for plan/validate wrappers)
- curl (for HTTP checks)
- dig (from bind9-dnsutils or dnsutils) for DNS checks

Usage
- Run static repository checks:
  ./scripts/validate.sh
- Run the terraform plan wrapper:
  ./scripts/plan.sh
- Run connectivity checks (static or live):
  ./scripts/test-connectivity.sh [static|live] [ENDPOINT_URL]

Notes
- Do NOT store credentials, service-account JSON, or absolute local paths in this directory. Use environment variables or CI secret stores.
- These scripts are intended as convenience helpers; consult `docs/operations/deployment-and-validation.md` and the top-level README for full runbooks.
- Agents and automation should follow the rules in `AGENTS.md` when invoking or modifying scripts.

- Progressive Disclosure (skill): [`Agents/skills/Progressive-Disclosure/SKILL.md`](Agents/skills/Progressive-Disclosure/SKILL.md) — Follow the skill's 4-tier model and metadata standards (TOML front matter, breadcrumbs, AI retrieval hints) when authoring or refactoring `scripts/` documentation. The skill includes templates and a checklist for validation.
