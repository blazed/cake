---
name: proton-pass
description: "Uses Proton Pass CLI safely for credentials and secrets. Use before invoking pass-cli or accessing Proton Pass authentication, vaults, shares, items, or credentials."
metadata:
  topic: Proton Pass
  keywords: ["proton-pass", "pass-cli", "credentials", "secrets", "vaults"]
  requires_tools: [bash]
---

# Proton Pass

Use `pass-cli` only when credentials are required for an explicitly requested task. The jailed Pi wrapper provides an isolated session directory, filesystem-backed session encryption, and, when configured on the host, an agenix-managed personal access token.

## Workflow

1. Before any vault, share, or item operation, run `pass-cli info`. Health and authentication recovery commands are exempt from this pre-check.
2. If the session is missing, expired, or reports an authentication error, run `pass-cli logout --force`, then `pass-cli login`, and verify recovery with `pass-cli info` before retrying the original operation.
3. After login, verify access when needed with:
   - `pass-cli vault list --output json`
   - `pass-cli share list --output json`
4. Set `PROTON_PASS_AGENT_REASON` to a brief, task-specific explanation for every command that requires it, including item reads and writes.
5. Prefer `--output json` whenever output needs programmatic parsing.
6. Read the complete error output before deciding whether to retry a failed command.

Keep retrieved secrets inside the narrowest possible command invocation. Avoid printing secret-bearing output; pass a value directly to the explicitly requested local operation when practical.

## Safety

- Never print, persist, or copy the personal access token into prompts, source files, task notes, logs, or agent memory.
- Avoid exposing retrieved credentials in responses or command output.
- Do not perform exploratory credential reads. Retrieve only the item and fields needed for the user's explicit task.
- Read the complete failure before retrying; do not blindly repeat authentication or vault commands.
