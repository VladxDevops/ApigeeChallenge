---
name: write-git-commit
description: >
  Writes one git commit for the Apigee Challenge repository. The message states
  what changed, why, and how it was checked, using transcripts.md, changelog.md,
  and docs/TROUBLESHOOTING as the task record. It stages only named paths and
  keeps secret values out of the index and the message by applying
  docs/security/security-model.md, AGENTS.md, and .gitignore. Use when the user
  asks to commit, write a commit, record this change in git, or /write-git-commit.
  Shared procedure for Grok, Gemini, Codex, and Gemma.
metadata:
  short-description: Write a sourced, non-leaking git commit
compatibility:
  assistants: [grok, gemini, codex, gemma]
---

# Write a git commit

Grok, Gemini, Codex, and Gemma follow this file as written. The agent that creates the commit puts its own name on the `Agent:` line. Use the shell `git` commands below. Do not invent a second commit format for a particular model.

Commit only when the user asked to commit or to record the current change in git.

## 1. Read the task record

The work being committed is already written down. Read these, in order, and stop once the entry matches the diff:

1. `transcripts.md` — session objective, findings, files, validation, and which agent did the work.
2. `changelog.md` — what changed, why, affected area, and validation.
3. `docs/TROUBLESHOOTING/` — only when the diff fixes a defect. List that directory and open the one file whose title matches the failure. `docs/TROUBLESHOOTING/agents.md` is empty; do not wait on it.

A match is the latest entry whose files or objective are the files in the diff. If none match, describe only the diff and set the trace line to `Trace: no matching entry in transcripts.md or changelog.md`. Do not attach an older session's reason to a new diff.

Take facts from that record. Do not add causes, commands, or results that the record and the diff do not support.

## 2. Inspect the change

From the repository root:

```bash
git status
git diff
git diff --cached
git log -8 --oneline
```

The diff decides what changed. The task record supplies why and validation when it matches this diff. If they disagree, follow the diff for the change list and omit the conflicting sentence from the record.

## 3. Keep secrets out

Secret classes and the never-commit list are defined in:

- `docs/security/security-model.md`, section "5. Secrets"
- `AGENTS.md`, section "13. Security Model", subsection "Secrets"
- `.gitignore` (state, `*.tfvars`, keys, `.env`, service-account JSON, and the ignored trees)
- `internalDocumentation/Security/Shiftleft.md`, section "2) Commit / pre-commit level" (Gitleaks or TruffleHog when the tool is installed)

Read those sections in this session before staging. Apply them. Do not paste their lists into the commit message.

Then:

1. Choose paths by name. Do not run `git add -A` or `git add .`.
2. Drop any path `.gitignore` excludes as state, variables, keys, env files, or credentials. If such a path is already tracked, stop and tell the user the path and the class. Do not stage more of it.
3. Read every remaining hunk. If a new or changed line carries a secret value, stop the commit. Report the path, the line number, and the class from the security sections (password, token, private key, service-account key, API secret, tfvars secret, or state). Do not print the value, a prefix of it, or an encoding of it.
4. When a scanner from the Shift Left note is installed, run it on the paths you intend to stage. A finding stops the commit the same way as step 3.
5. The message may name repo-relative paths, Terraform addresses, variable names, IAM role names, resource names, HTTP status classes, and the troubleshooting file path. It may repeat an identifier only when that identifier is already in the matching transcript, changelog entry, troubleshooting note, or the diff.
6. The message must not contain secret values, `Authorization` headers, connection strings with userinfo, `terraform show` or state JSON, raw `tfvars` assignments, absolute home-directory paths, or a copied sentence from the task record that already includes a secret. If the record leaked a value, name the class and cite the file path instead of copying the sentence.

Service-account emails and Secret Manager secret ids that are already in the matched record or the diff are names. Key material, tokens, and passwords are not.

## 4. Write the message

Subject: one imperative line, about 72 characters, stating the outcome.

Body, in this order. Omit a section that has nothing to add. Each sentence must add a fact the subject and the earlier sections do not already state.

- **What.** Bullets for the behavior and the files the diff changes. One fact per bullet.
- **Why.** The reason from the matched changelog "Why" or transcript objective, in one short paragraph. Do not repeat the file list.
- **Troubleshooting.** One line, only for a defect fix: symptom name and the path under `docs/TROUBLESHOOTING/`. Do not paste the error body.
- **Validation.** Checks the matched record says were run, with the result. If a check failed or was skipped, say so and give the recorded reason. Do not claim a check that was not run.
- **Trace.** Date and source files used (`transcripts.md`, `changelog.md`, troubleshooting path).
- **Agent.** `Grok`, `Gemini`, `Codex`, or `Gemma`.

Use repo-relative paths. Do not restate the subject in the body. Do not quote both the transcript and the changelog when they say the same thing; keep the more specific sentence and cite the file on the trace line.

```text
Accept the Apigee tenant on the southbound PSC attachment

Southbound calls returned 503 TARGET_CONNECT_TIMEOUT while the producer
held the tenant connection in PENDING.

- Added the tenant project to the producer consumer accept list.
- Added the PSC NAT ingress allow in the security module.

Troubleshooting: docs/TROUBLESHOOTING/Apigee/Apigee Connectivity & Ingress TS.md
Validation: service attachment reported ACCEPTED; a northbound request returned HTTP 200.
Trace: changelog.md 2026-10-06; transcripts.md same date.
Agent: Gemma
```

That example is the shape. Replace every fact with the current diff and the matched record.

## 5. Create the commit

Stage the named paths, then commit with a heredoc so the body stays literal:

```bash
git add path/to/file path/to/other
git commit -m "$(cat <<'EOF'
Subject line here

Body here.

Agent: Grok
EOF
)"
git status
```

Do not update git config. Do not push. Do not use `--no-verify` unless the user explicitly asked.

Amend only when the user asked to amend, HEAD was created by you in this session, and the commit has not been pushed. If a hook rejects the commit, fix the problem and make a new commit.

After the commit, report the hash, the subject, and the paths that were committed.
