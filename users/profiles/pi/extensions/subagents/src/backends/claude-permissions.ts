import {
  CLAUDE_PERMISSION_POLICIES,
  type ClaudePermissionPolicy,
} from "../domain.ts";

export const DEFAULT_CLAUDE_PERMISSION_POLICY: ClaudePermissionPolicy = "full";

export interface ClaudePermissionResolution {
  policy: ClaudePermissionPolicy;
  source: "flag" | "environment" | "file" | "default";
  warning?: string;
}

function isPolicy(value: unknown): value is ClaudePermissionPolicy {
  return typeof value === "string" && CLAUDE_PERMISSION_POLICIES.includes(value as ClaudePermissionPolicy);
}

export function resolveClaudePermissionPolicy(input: {
  flag?: unknown;
  environment?: unknown;
  file?: unknown;
}): ClaudePermissionResolution {
  const candidates = [
    ["flag", input.flag],
    ["environment", input.environment],
    ["file", input.file],
  ] as const;
  const invalid: string[] = [];
  for (const [source, value] of candidates) {
    if (value === undefined || value === null || value === "") continue;
    if (isPolicy(value)) {
      return {
        policy: value,
        source,
        ...(invalid.length > 0 ? { warning: invalid.join(" ") } : {}),
      };
    }
    invalid.push(
      `Invalid Claude subagent permission policy ${JSON.stringify(value)} from ${source}; ignored. Expected one of: ${CLAUDE_PERMISSION_POLICIES.join(", ")}.`,
    );
  }
  if (invalid.length > 0) {
    return {
      policy: "dontAsk",
      source: "default",
      warning: `${invalid.join(" ")} No valid lower-precedence policy exists; failing closed with dontAsk.`,
    };
  }
  return { policy: DEFAULT_CLAUDE_PERMISSION_POLICY, source: "default" };
}

/**
 * Headless children cannot answer approval prompts. `full` preserves autonomous
 * implementation capability as an explicit policy; `dontAsk` is the restrictive
 * non-blocking alternative. `acceptEdits` and `plan` may still deny operations.
 */
export function claudePermissionOptions(policy: ClaudePermissionPolicy): {
  permissionMode: "bypassPermissions" | "dontAsk" | "acceptEdits" | "plan";
  allowDangerouslySkipPermissions?: true;
} {
  if (policy === "full") {
    return {
      permissionMode: "bypassPermissions",
      allowDangerouslySkipPermissions: true,
    };
  }
  return { permissionMode: policy };
}
