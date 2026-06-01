/**
 * Per-stage model routing for workflows.
 * Allows different phases to use different models.
 */

export interface ModelRoute {
  /** Phase name pattern (regex or exact match). */
  phasePattern: string;
  /** Model to use for this phase. */
  model: string;
  /** Whether to use regex matching. */
  useRegex?: boolean;
}

export interface ModelRoutingConfig {
  /** Default model for all phases. */
  defaultModel?: string;
  /** Per-phase model overrides. */
  routes: ModelRoute[];
}

/**
 * Resolve which model to use for a given phase.
 */
export function resolveModelForPhase(phase: string | undefined, config: ModelRoutingConfig): string | undefined {
  if (!phase || !config.routes.length) {
    return config.defaultModel;
  }

  for (const route of config.routes) {
    if (route.useRegex) {
      try {
        const regex = new RegExp(route.phasePattern, "i");
        if (regex.test(phase)) {
          return route.model;
        }
      } catch {
        // Invalid regex, skip
      }
    } else {
      if (phase.toLowerCase().includes(route.phasePattern.toLowerCase())) {
        return route.model;
      }
    }
  }

  return config.defaultModel;
}

/**
 * Build model routing instructions for a workflow agent.
 */
export function buildModelRoutingInstructions(
  phase: string | undefined,
  config: ModelRoutingConfig,
): string | undefined {
  const model = resolveModelForPhase(phase, config);
  if (!model) return undefined;
  return `Use model: ${model}`;
}

/**
 * Parse model routing from workflow meta phases.
 */
export function parseModelRoutingFromMeta(phases?: Array<{ title: string; model?: string }>): ModelRoutingConfig {
  const routes: ModelRoute[] = [];

  if (phases) {
    for (const phase of phases) {
      if (phase.model) {
        routes.push({
          phasePattern: phase.title,
          model: phase.model,
        });
      }
    }
  }

  return { routes };
}
