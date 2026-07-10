/**
 * Formatting helpers for the footer extension.
 */

import { isAbsolute, relative, resolve, sep } from "node:path";

/** Format the working directory, replacing the user's home directory with ~. */
export function formatDirectory(cwd: string, home: string): string {
  if (!home) return cwd;

  const resolvedCwd = resolve(cwd);
  const resolvedHome = resolve(home);
  const relativeToHome = relative(resolvedHome, resolvedCwd);
  const isInsideHome =
    relativeToHome === "" ||
    (relativeToHome !== ".." && !relativeToHome.startsWith(`..${sep}`) && !isAbsolute(relativeToHome));

  if (!isInsideHome) return cwd;
  return relativeToHome === "" ? "~" : `~${sep}${relativeToHome}`;
}
/** Format token count with k/M suffixes. */
export function formatTokens(n: number): string {
  if (n < 1000) return String(n);
  if (n < 1_000_000) {
    const k = n / 1000;
    const formatted = k < 10_000 ? k.toFixed(1) : Math.round(k).toFixed(0);
    return `${formatted.replace(/\.0$/, "")}k`;
  }
  const m = n / 1_000_000;
  const formatted = m < 10_000 ? m.toFixed(1) : Math.round(m).toFixed(0);
  return `${formatted.replace(/\.0$/, "")}M`;
}

/** Format cost in USD. */
export function formatCost(usd: number): string {
  if (usd === 0) return "$0";
  if (usd < 0.01) return `$${usd.toFixed(4)}`;
  if (usd < 1) return `$${usd.toFixed(3)}`;
  return `$${usd.toFixed(2)}`;
}

// ── Model-name formatting (following little-footer's approach) ──

/** Known provider names mapped to human-readable display names. */
const KNOWN_PROVIDERS: Record<string, string> = {
  anthropic: "Anthropic",
  openai: "OpenAI",
  "openai-codex": "OpenAI Codex",
  google: "Google",
  deepseek: "DeepSeek",
  "opencode-go": "OpenCodeGo",
  xai: "xAI",
  groq: "Groq",
  openrouter: "OpenRouter",
  mistralai: "MistralAI",
  github: "GitHub",
};

/** Acronyms that should stay uppercase (e.g. GPT → GPT, not Gpt). */
const ACRONYMS = new Set(["gpt", "ai", "llm", "api", "moe", "ssm", "vl"]);

/**
 * Set of lowercase words that indicate a model name already implies its
 * provider (e.g. "deepseek" in "deepseek-v4-flash").  Built from provider
 * keys and display names so we don't show "OpenCodeGo DeepSeek V4 Flash".
 */
const PROVIDER_INDICATORS = new Set<string>();
for (const [key, display] of Object.entries(KNOWN_PROVIDERS)) {
  PROVIDER_INDICATORS.add(key.toLowerCase());
  if (display) PROVIDER_INDICATORS.add(display.toLowerCase());
}

/** Title-case a single word, preserving known acronyms. */
function titleCaseWord(word: string): string {
  const lower = word.toLowerCase();
  if (ACRONYMS.has(lower)) return lower.toUpperCase();
  // Words starting with a digit stay unchanged
  if (/^\d/.test(word)) return word;
  return word.charAt(0).toUpperCase() + word.slice(1);
}

/**
 * Format a model ID into a human-readable display name.
 *
 * Uses the same approach as little-footer: title-cases each segment of the
 * model name (split on - and _) and prepends the provider label when known
 * but not already implied by the model name itself.
 *
 * @param id - Model ID (may include "provider/" prefix).
 * @param fallbackProvider - Provider from ctx.model?.provider, used when the
 *   model ID doesn't carry a provider prefix.
 */
export function formatModelDisplay(
  id: string | undefined,
  fallbackProvider?: string,
): string | null {
  if (!id) return null;
  const trimmed = id.trim();
  if (!trimmed) return null;

  const slashIndex = trimmed.indexOf("/");
  let providerLabel: string | undefined;
  let modelPart: string;

  if (slashIndex !== -1) {
    const raw = trimmed.slice(0, slashIndex);
    providerLabel = KNOWN_PROVIDERS[raw] ?? titleCaseWord(raw);
    modelPart = trimmed.slice(slashIndex + 1);
  } else {
    if (fallbackProvider) {
      providerLabel = KNOWN_PROVIDERS[fallbackProvider] ?? titleCaseWord(fallbackProvider);
    }
    modelPart = trimmed;
  }

  // Title-case the model part, splitting on - and _
  const words = modelPart.split(/[-_]+/);
  const formattedModel = words.map(titleCaseWord).join(" ");

  // If the model name itself starts with a known provider name (e.g.
  // "DeepSeek" in "DeepSeek V4 Flash"), skip the explicit provider label
  // — it's redundant.
  const firstWord = words[0]?.toLowerCase();
  if (firstWord && PROVIDER_INDICATORS.has(firstWord)) {
    providerLabel = undefined;
  }

  const display = providerLabel
    ? `${providerLabel} ${formattedModel}`
    : formattedModel;

  if (display.length > 30) {
    return display.slice(0, 28) + "…";
  }
  return display;
}
