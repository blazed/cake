/**
 * Auto-workflow mode (ultracode equivalent).
 * Automatically decides when to use workflows based on task complexity.
 *
 * Wired in via an opt-in `/auto-workflow off|suggest|force` toggle (default off):
 * `installAutoWorkflow` registers the command and returns a controller that the
 * workflows-mode input hook (workflow-editor.ts) consults on each submit, using
 * `evaluateAutoWorkflow` to decide whether to nudge or force a workflow.
 */

import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

export interface AutoWorkflowConfig {
  /** Enable auto-workflow mode. */
  enabled: boolean;
  /** Minimum number of subtasks to trigger a workflow. */
  minSubtasks: number;
  /** Keywords that suggest workflow usage. */
  triggerKeywords: string[];
  /** Maximum complexity score before auto-triggering. */
  complexityThreshold: number;
}

const DEFAULT_CONFIG: AutoWorkflowConfig = {
  enabled: false,
  minSubtasks: 3,
  triggerKeywords: [
    "workflow",
    "parallel",
    "fan-out",
    "audit",
    "migrate",
    "review",
    "research",
    "analyze all",
    "check every",
    "sweep",
    "batch",
    "bulk",
  ],
  complexityThreshold: 7,
};

/**
 * Analyze a task description and determine if it should use a workflow.
 */
export function shouldUseWorkflow(
  taskDescription: string,
  config: Partial<AutoWorkflowConfig> = { enabled: true },
): { useWorkflow: boolean; confidence: number; reason: string } {
  const cfg = { ...DEFAULT_CONFIG, ...config };

  if (!cfg.enabled) {
    return { useWorkflow: false, confidence: 0, reason: "Auto-workflow disabled" };
  }

  const lower = taskDescription.toLowerCase();

  // Check for explicit workflow keywords
  const keywordMatches = cfg.triggerKeywords.filter((kw) => lower.includes(kw));
  if (keywordMatches.length > 0) {
    return {
      useWorkflow: true,
      confidence: Math.min(0.5 + keywordMatches.length * 0.15, 1),
      reason: `Matched keywords: ${keywordMatches.join(", ")}`,
    };
  }

  // Analyze complexity indicators
  const complexityIndicators = [
    { pattern: /\b(all|every|each|entire|whole)\b/i, weight: 2 },
    { pattern: /\b(files?|directories|folders?|modules?|components?|endpoints?)\b/i, weight: 1.5 },
    { pattern: /\b(parallel|concurrent|simultaneously)\b/i, weight: 2 },
    { pattern: /\b(review|audit|check|verify|validate)\b/i, weight: 1 },
    { pattern: /\b(migrate|refactor|update|modify|change)\b/i, weight: 1.5 },
    { pattern: /\b(research|investigate|analyze|compare)\b/i, weight: 1 },
    { pattern: /\d+\s*(files?|items?|tasks?|components?)/i, weight: 2 },
    { pattern: /\b(across|throughout|cross-cutting)\b/i, weight: 1.5 },
  ];

  let complexityScore = 0;
  for (const indicator of complexityIndicators) {
    if (indicator.pattern.test(taskDescription)) {
      complexityScore += indicator.weight;
    }
  }

  // Estimate subtask count
  const subtaskIndicators = [
    /\bfirst\b/gi,
    /\bthen\b/gi,
    /\bfinally\b/gi,
    /\bafter\b/gi,
    /\bnext\b/gi,
    /\balso\b/gi,
    /\bstep \d/gi,
  ];

  let estimatedSubtasks = 1;
  for (const pattern of subtaskIndicators) {
    const matches = taskDescription.match(pattern);
    if (matches) estimatedSubtasks += matches.length;
  }

  if (complexityScore >= cfg.complexityThreshold || estimatedSubtasks >= cfg.minSubtasks) {
    return {
      useWorkflow: true,
      confidence: Math.min(complexityScore / 10, 1),
      reason: `Complexity score: ${complexityScore}, estimated subtasks: ${estimatedSubtasks}`,
    };
  }

  return {
    useWorkflow: false,
    confidence: 0.3,
    reason: `Below threshold (complexity: ${complexityScore}, subtasks: ${estimatedSubtasks})`,
  };
}

/**
 * Generate a workflow script suggestion from a task description.
 *
 * The task text is embedded via JSON.stringify (a safe double-quoted JS string
 * literal that handles quotes/backslashes/newlines), never via fragile manual
 * single-quote escaping — so a task with `'`, `\`, or a newline can't break or
 * inject into the generated script.
 */
export function suggestWorkflowScript(taskDescription: string): string {
  const descLit = JSON.stringify(taskDescription.slice(0, 100));
  const taskLit = JSON.stringify(taskDescription.slice(0, 80));
  return `export const meta = {
  name: 'auto_generated',
  description: ${descLit},
  phases: [
    { title: 'Analyze' },
    { title: 'Execute' },
    { title: 'Verify' },
  ],
};

phase('Analyze');
const analysis = await agent(
  'Analyze this task and break it into subtasks: ' + ${taskLit},
  { label: 'task analysis' }
);

phase('Execute');
const results = await parallel([
  () => agent('Execute subtask 1 based on: ' + analysis, { label: 'subtask-1' }),
  // Add more subtasks as needed
]);

phase('Verify');
const verification = await agent(
  'Verify these results are correct: ' + JSON.stringify(results),
  { label: 'verification' }
);

return { analysis, results, verification };`;
}

/** Auto-workflow runtime mode, toggled by the `/auto-workflow` command. */
export type AutoWorkflowMode = "off" | "suggest" | "force";

/** Live view of the auto-workflow mode, shared with the workflows-mode input hook. */
export interface AutoWorkflowController {
  getMode(): AutoWorkflowMode;
  setMode(mode: AutoWorkflowMode): void;
}

/** Result of evaluating a submitted message against the current auto-workflow mode. */
export interface AutoWorkflowDecision {
  action: "none" | "suggest" | "force";
  reason?: string;
  /** Starter script for "force"; the caller composes it into the forced prompt. */
  skeleton?: string;
}

/**
 * Minimum shouldUseWorkflow confidence to auto-FORCE a workflow. "suggest" fires
 * on any positive detection; forcing is held to a higher bar so borderline
 * messages only get a nudge, never a silent rewrite.
 */
const AUTO_FORCE_MIN_CONFIDENCE = 0.6;

/**
 * Decide what auto-workflow should do for a submitted message. Pure (no UI): the
 * caller acts on the result. Returns "none" when off, empty, or not detected.
 */
export function evaluateAutoWorkflow(text: string, mode: AutoWorkflowMode): AutoWorkflowDecision {
  if (mode === "off" || !text.trim()) return { action: "none" };
  const decision = shouldUseWorkflow(text);
  if (!decision.useWorkflow) return { action: "none" };
  if (mode === "force" && decision.confidence >= AUTO_FORCE_MIN_CONFIDENCE) {
    return { action: "force", reason: decision.reason, skeleton: suggestWorkflowScript(text) };
  }
  return { action: "suggest", reason: decision.reason };
}

/**
 * Register the `/auto-workflow [off|suggest|force|status]` command (mirrors
 * `/footer`) and return a controller the workflows-mode input hook reads on each
 * submit. Default mode is "off", so nothing changes until the user opts in.
 */
export function installAutoWorkflow(pi: ExtensionAPI): AutoWorkflowController {
  let mode: AutoWorkflowMode = "off";
  pi.registerCommand("auto-workflow", {
    description: "Auto-detect workflow-worthy messages. Usage: /auto-workflow [off|suggest|force|status]",
    handler: async (args: string, ctx: ExtensionCommandContext) => {
      const sub = args.trim().toLowerCase() || "status";
      if (sub === "status") {
        ctx.ui.notify(`auto-workflow: ${mode}`, "info");
      } else if (sub === "off" || sub === "suggest" || sub === "force") {
        mode = sub;
        ctx.ui.notify(`auto-workflow: ${mode}`, "info");
      } else {
        ctx.ui.notify(`auto-workflow: unknown "${sub}". Use off|suggest|force|status.`, "warning");
      }
    },
  });
  return {
    getMode: () => mode,
    setMode: (m: AutoWorkflowMode) => {
      mode = m;
    },
  };
}
