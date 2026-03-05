---
name: agent-toolkit-onboarding
description: Use when users ask which local terminal tools to use for coding-agent workflows, how to choose among tools, or how to combine tools by task across discovery, refactor, validation, review, API, and observability loops.
---

# Agent Toolkit Onboarding

Use this skill to educate the model on the repository's tool ecosystem and recommend the right tool combinations for each coding-agent workflow.

## When To Trigger

Trigger when users ask:

- which tool is best for a task
- alternatives to a current command
- safer/faster tool combinations
- discovery/refactor/review/debug workflow design
- minimal tool stacks for a team or repo

## Workflow

1. Read [TOOL-CATALOG.md](./references/TOOL-CATALOG.md) first.
2. Map the user request to an SDLC stage:
   - discovery, parsing, refactor, review, automation, API/debug, observability
3. Recommend:
   - one primary tool
   - one to two companion tools
   - one fallback when portability matters
4. Explain tradeoffs:
   - speed, safety, ergonomics, and cross-platform availability
5. Only when asked for install/CLI wiring, switch to repo CLI docs (`README.md`, `agent-tools.sh`, `install.sh`, `install.ps1`).

## Guardrails

- Prefer minimal tool sets over broad bundles.
- Separate "default included" tools from "candidate/optional" tools.
- Do not assume every tool is mapped on every package manager.
- Keep recommendations task-first, not tool-first.

## Catalog Maintenance

Canonical source:

- [skills/references/tool-list.tsv](./references/tool-list.tsv)

Regenerate catalog:

```bash
bash skills/scripts/generate-tool-catalog.sh
```

## Repo Anchors

- Tool knowledge catalog: `skills/references/TOOL-CATALOG.md`
- Candidate rollout notes: `docs/TOOL-CANDIDATES.md`
- Main project narrative: `README.md`
