---
name: example-skill
description: Template for self-authored Pi skills managed by Nix. Replace with a real skill; the description should explain what the skill does and when Pi should reach for it.
metadata:
  tags: ["template"]
---

# Example Skill

Starter template for self-authored Pi skills. Skills live in
`users/profiles/pi/skills/<name>/SKILL.md` in the cake repo and are symlinked
into `~/.pi/agent/skills/` (auto-discovered by Pi). Edit or delete this one.

## Usage

Describe the workflow, commands, or references the agent should follow. Put any
helper scripts under `scripts/` and longer docs under `references/` beside this
file.

See https://pi.dev/docs/latest/skills for the full SKILL.md schema.
