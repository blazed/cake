---
name: skill-authoring
description: "Create or edit SKILL.md files for the shared Pi/Claude skill set. Use when authoring a new skill or changing an existing one."
disable-model-invocation: true
---

# Skill authoring

Skills live in `users/profiles/agents/skills/<name>/` and are installed for both Pi and Claude Code, so keep them agent-neutral: no agent-specific syntax (such as Claude's `` !`cmd` `` interpolation), no named subagent models, and plain shell commands the agent runs itself.

## Layout

```
<name>/
├── SKILL.md       # frontmatter + workflow, aim for ~120 lines
├── references/    # deep material, linked from SKILL.md, loaded on demand
└── scripts/       # deterministic helpers, invoked by absolute path
```

## Frontmatter conventions

```yaml
---
name: my-skill          # kebab-case, matches the directory name
description: "Does X. Use when Y."   # quoted, starts with a verb, concrete triggers
disable-model-invocation: true        # only for skills the user invokes explicitly
---
```

`allowed-tools` is not a security boundary; do not rely on it.

## Body

- Lead with the workflow: numbered steps with concrete commands or snippets.
- Skip concepts the agent already knows; keep only project conventions and gotchas.
- Move long reference material to `references/`; never duplicate it in SKILL.md.
- No README, changelog, or other files the agent never reads.
