---
name: skill-authoring
description: "Create SKILL.md files that teach the agent new domains. Use when authoring a new pi skill with frontmatter, body structure, and references."
metadata:
  topic: Pi Skill Authoring
  keywords: ["skill", "author", "create", "improve", "domain"]
---

# Pi Skills

Skills are Markdown files (`SKILL.md`) that teach the agent how to do something it doesn't know by default. Each skill covers one or more use cases within a single domain — e.g., "NixOS configuration management" with sub-areas for system updates, home manager, and package search. The agent loads the full file when the user's request matches the trigger description.

## File Layout

```
my-skill/
├── SKILL.md              # Frontmatter + workflow instructions (aim for ~120 lines)
├── references/           # Deep docs loaded on demand (API specs, advanced patterns)
└── scripts/              # Helper scripts the agent runs directly
```

Assets go in `assets/` for templates and files the agent uses in outputs. Scripts in `scripts/` are deterministic code — not rewritten each invocation.

## Frontmatter

Pi currently requires only `name` and `description`. Put custom conventions under `metadata`; Pi ignores them, but they remain useful human-readable metadata.

### Required Fields

```yaml
---
name: my-skill-name # kebab-case, max 64 chars
description: "Does X. Use when Y."
metadata:
  keywords: ["keyword1", "keyword2", "keyword3"] # optional human hints
---
```

- `name`: lowercase letters, numbers, hyphens only. No leading/trailing hyphens.
- `description`: quoted string. First sentence starts with a verb. Second starts with "Use when".
- `metadata.keywords`: optional human convention; Pi does not score or match on it.

### Optional Conventions

```yaml
metadata:
  topic: Conventional Commits # human display/grouping hint
  related: [other-skill] # related skills to consider manually
  requires_tools: [read, bash] # tool dependency note
disable-model-invocation: true # Pi-supported: hide from automatic prompt; use /skill:name
```

Pi currently only acts on `disable-model-invocation`; `metadata.*` fields are convention-only.

## Body Structure (aim for ~120 lines)

```markdown
# Skill Name

One-line summary of the domain this skill covers.

## Workflow / Commands

Step-by-step examples or command reference with inline code snippets.

## Details

Common variations, edge cases, or tricky parts specific to this domain.

## Constraints / Best Practices

Rules, gotchas, and things the agent must do (or not do).

See [deep reference](references/DEEP.md) for API specs and advanced usage.
```

- **Workflow/Commands**: numbered steps with concrete inline examples — command, code snippet, or config.
- **Details**: short context for variations on the main use cases.
- Link to `references/` for anything deep. One level of linking only.

## Examples from Existing Skills

**Good — focused domain, multiple use cases:**

```yaml
# nh: one domain (Nix operations), three sub-domains (system updates, home manager, package search)
description: "Switches NixOS/Home Manager configurations, cleans old generations, and performs system maintenance. Use when running os/home switch, pruning the Nix store, or managing system generations."
```

**Good — single use case within a domain:**

```yaml
# transcribe-audio: one domain (audio transcription), one primary use case
description: "Transcribes audio files to text using whisper-cpp. Use when converting speech to text, transcribing podcasts, lectures, or meetings."
```

## Validation Checklist

- [ ] `name` is kebab-case (matching directory name is recommended for portability)
- [ ] `description` is a quoted string with verb-first sentence + "Use when..." clause
- [ ] `metadata.keywords`, if present, are useful human hints
- [ ] `metadata.topic`, `metadata.related`, and `metadata.requires_tools` are convention-only
- [ ] Body aims for ~120 lines (move excess to `references/`)
- [ ] At least one concrete inline example per key concept
- [ ] No duplicated content between SKILL.md and references
- [ ] All file links resolve to existing paths

## Common Mistakes

- Description uses `>` chevron instead of `"quoted"` — convert to quoted string
- Missing "Use when..." clause — add trigger conditions
- Duplicate content between SKILL.md and references — keep detail only in references
- Long explanations of concepts the agent already knows — delete them
- Extra files the agent never reads (README, changelog) — remove them
