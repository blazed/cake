---
name: skill-authoring
description: "Create SKILL.md files that teach the agent new domains. Use when authoring a new pi skill with frontmatter, body structure, and references."
disable-model-invocation: true
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

The Agent Skills format declares `name` and `description`. Pi 0.82 requires a non-empty description but can fall back to the directory name when `name` is missing; this repository requires both for portability. Put local conventions under `metadata`, which Pi ignores at runtime.

### Required Fields

```yaml
---
name: my-skill-name # kebab-case, max 64 chars
description: "Does X. Use when Y."
metadata:
  keywords: ["keyword1", "keyword2", "keyword3"] # optional human hints
---
```

- `name`: Agent Skills and this repository require lowercase letters, numbers, and hyphens with no leading/trailing or consecutive hyphens; Pi is lenient and may warn or fall back to the directory name.
- `description`: Pi requires a non-empty value. This repository convention quotes it, starts with a verb, and states concrete trigger conditions in a second sentence such as "Use when...".
- `metadata.keywords`: optional repository convention; Pi does not score or match on it.

### Optional Fields and Conventions

```yaml
license: MIT # Agent Skills field; ignored by Pi 0.82 at runtime
compatibility: "Requires Nushell and JJ" # Agent Skills field, max 500 chars; ignored by Pi 0.82
allowed-tools: read bash # experimental Agent Skills field; ignored by Pi 0.82
disable-model-invocation: true # Pi-supported: hide from automatic prompt; use /skill:name
metadata:
  topic: Conventional Commits # human display/grouping hint
  related: [other-skill] # related skills to consider manually
  requires_tools: [read, bash] # convention-only dependency note
```

Pi 0.82 acts on `disable-model-invocation`. It does not enforce `allowed-tools` or use `license` or `compatibility` at runtime; never treat `allowed-tools` as a security boundary. Other `metadata.*` fields are convention-only.

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

If deeper material is needed, link to a real file under `references/`, such as `references/API.md`.
```

- **Workflow/Commands**: numbered steps with concrete inline examples — command, code snippet, or config.
- **Details**: short context for variations on the main use cases.
- Link to real files under `references/` for deep material. Keep the link graph shallow when practical; this is a maintainability preference, not a Pi schema rule.

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
- [ ] `description` is non-empty and, by repository convention, quoted with clear trigger conditions
- [ ] `metadata.keywords`, if present, are useful human hints
- [ ] `metadata.topic`, `metadata.related`, and `metadata.requires_tools` are convention-only
- [ ] Optional standard fields are valid, and only `disable-model-invocation` is relied on for Pi 0.82 behavior
- [ ] Body aims for ~120 lines (move excess to `references/`)
- [ ] At least one concrete inline example per key concept
- [ ] No duplicated content between SKILL.md and references
- [ ] All file links resolve to existing paths

## Common Mistakes

- Description is vague or omits when the skill should load — add specific trigger conditions
- YAML style differs from the repository's quoted-description convention — normalize it when editing local skills
- Duplicate content between SKILL.md and references — keep detail only in references
- Long explanations of concepts the agent already knows — delete them
- Extra files the agent never reads (README, changelog) — remove them
