import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join, normalize, resolve } from "node:path";

export interface PlanState {
  active: boolean;
  planSlug: string | null;
  planFilePath: string | null;
  lastTransition: "entered" | "approved" | "cancelled" | null;
  lastApprovedPlanFilePath: string | null;
  hasExitedPlanModeInSession: boolean;
}

export interface TodoItem {
  step: number;
  text: string;
  completed: boolean;
}

const ADJECTIVES = [
  "bold",
  "calm",
  "clear",
  "deep",
  "fine",
  "keen",
  "lean",
  "safe",
  "sharp",
  "steady",
  "tidy",
  "wise",
];

const NOUNS = [
  "bear",
  "bird",
  "bolt",
  "core",
  "dawn",
  "field",
  "forge",
  "harbor",
  "map",
  "path",
  "root",
  "wave",
];

const MUTATING_PATTERNS = [
  /\brm\b/i,
  /\brmdir\b/i,
  /\bmv\b/i,
  /\bcp\b/i,
  /\bmkdir\b/i,
  /\btouch\b/i,
  /\bchmod\b/i,
  /\bchown\b/i,
  /\bchgrp\b/i,
  /\bln\b/i,
  /\btee\b/i,
  /\btruncate\b/i,
  /\bdd\b/i,
  /\bshred\b/i,
  /\b(bash|sh|zsh|fish|nu|python|python3|node|ruby|perl)\s+-c\b/i,
  /\bnpm\s+(install|uninstall|update|ci|link|publish)\b/i,
  /\byarn\s+(add|remove|install|publish)\b/i,
  /\bpnpm\s+(add|remove|install|publish)\b/i,
  /\bpip\s+(install|uninstall)\b/i,
  /\bnix\s+(build|develop|flake\s+update|run|shell|profile|collect-garbage)\b/i,
  /\bnh\s+(os|home)\s+switch\b/i,
  /\bapt(-get)?\s+(install|remove|purge|update|upgrade)\b/i,
  /\bbrew\s+(install|uninstall|upgrade)\b/i,
  /\bgit\s+(add|commit|push|pull|merge|rebase|reset|checkout|switch|branch\s+-[dD]|stash|cherry-pick|revert|tag|init|clone)\b/i,
  /\bjj\s+(new|describe|desc|commit|bookmark|git\s+push|git\s+fetch|rebase|squash|split|abandon|restore|undo|operation\s+restore)\b/i,
  /\bsudo\b/i,
  /\bsu\b/i,
  /\bkill\b/i,
  /\bpkill\b/i,
  /\bkillall\b/i,
  /\breboot\b/i,
  /\bshutdown\b/i,
  /\bsystemctl\s+(start|stop|restart|enable|disable)\b/i,
  /\bservice\s+\S+\s+(start|stop|restart)\b/i,
];


export const DEFAULT_PLAN_ROOT = join(homedir(), ".pi", "agent", "plans");

export function createInitialState(): PlanState {
  return {
    active: false,
    planSlug: null,
    planFilePath: null,
    lastTransition: null,
    lastApprovedPlanFilePath: null,
    hasExitedPlanModeInSession: false,
  };
}

export function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 48) || "workspace";
}

export function generateSlug(random: () => number = Math.random): string {
  const adj = ADJECTIVES[Math.floor(random() * ADJECTIVES.length)];
  const noun = NOUNS[Math.floor(random() * NOUNS.length)];
  return `${adj}-${noun}`;
}

export function ensurePlanDir(cwd: string, root = DEFAULT_PLAN_ROOT): string {
  const dir = join(root, slugify(basename(cwd) || cwd));
  mkdirSync(dir, { recursive: true });
  return dir;
}

export function generateUniquePlanPath(cwd: string): { slug: string; path: string } {
  const dir = ensurePlanDir(cwd);
  for (let i = 0; i < 10; i++) {
    const slug = generateSlug();
    const path = join(dir, `${slug}.md`);
    if (!existsSync(path)) return { slug, path };
  }
  const slug = `${generateSlug()}-${Date.now()}`;
  return { slug, path: join(dir, `${slug}.md`) };
}

export function readPlan(path: string | null): string | null {
  if (!path) return null;
  try {
    return readFileSync(path, "utf-8");
  } catch {
    return null;
  }
}

export function writePlan(path: string, content: string): void {
  mkdirSync(resolve(path, ".."), { recursive: true });
  writeFileSync(path, content, "utf-8");
}

export function samePath(a: string | undefined, b: string | null): boolean {
  if (!a || !b) return false;
  return normalize(resolve(a)) === normalize(resolve(b));
}

export function isSafeReadOnlyCommand(command: string): boolean {
  const trimmed = command.trim();
  if (!trimmed) return false;

  // Shell parsing is a losing game for an extension. Use a conservative
  // blacklist for high-confidence mutations, and otherwise rely on the plan-mode
  // system prompt plus write/edit tool gating. This avoids blocking normal
  // read-only discovery pipelines (`find | sed | head`, `pi --help`, etc.).
  if (/`|\$\(/.test(trimmed)) return false;
  if (hasUnsafeRedirection(trimmed)) return false;

  const unquoted = stripQuotedStrings(trimmed);
  return !MUTATING_PATTERNS.some((pattern) => pattern.test(unquoted));
}

function hasUnsafeRedirection(command: string): boolean {
  let quote: "'" | '"' | null = null;

  for (let i = 0; i < command.length; i++) {
    const char = command[i];

    if (quote) {
      if (char === quote) quote = null;
      continue;
    }

    if (char === "'" || char === '"') {
      quote = char;
      continue;
    }

    if (char !== ">") continue;

    const prefix = command.slice(Math.max(0, i - 2), i).trim();
    const suffix = command.slice(i + 1).trimStart();
    // Redirecting output to /dev/null is read-only noise suppression.
    // This covers `>/dev/null`, `1>/dev/null`, `2>/dev/null`, and `2>&1`.
    if (suffix.startsWith("/dev/null")) continue;
    if ((prefix === "2" || prefix === "1") && suffix.startsWith("&1")) continue;

    return true;
  }

  return false;
}

function stripQuotedStrings(command: string): string {
  let output = "";
  let quote: "'" | '"' | null = null;

  for (const char of command) {
    if (quote) {
      if (char === quote) quote = null;
      continue;
    }

    if (char === "'" || char === '"') {
      quote = char;
      output += " ";
      continue;
    }

    output += char;
  }

  return output;
}

export function extractPlanTitle(content: string): string {
  const title = content.match(/^#\s+Plan:\s*(.+)$/im)?.[1]?.trim();
  return title || "Approved plan";
}

export function extractTodoItems(content: string): TodoItem[] {
  const items: TodoItem[] = [];
  const taskLines = content.match(/^\s*- \[ \]\s+(.+)$/gim) ?? [];
  for (const line of taskLines) {
    const text = line.replace(/^\s*- \[ \]\s+/, "").trim();
    if (text.length > 3) items.push({ step: items.length + 1, text: truncate(text), completed: false });
  }

  if (items.length > 0) return items;

  const numbered = content.match(/^\s*\d+[.)]\s+(.+)$/gm) ?? [];
  for (const line of numbered) {
    const text = line.replace(/^\s*\d+[.)]\s+/, "").trim();
    if (text.length > 3) items.push({ step: items.length + 1, text: truncate(text), completed: false });
  }
  return items;
}

export function markCompletedSteps(text: string, items: TodoItem[]): number {
  let count = 0;
  for (const match of text.matchAll(/\[DONE:(\d+)\]/gi)) {
    const step = Number(match[1]);
    const item = items.find((candidate) => candidate.step === step);
    if (item && !item.completed) {
      item.completed = true;
      count++;
    }
  }
  return count;
}

function truncate(text: string): string {
  const cleaned = text.replace(/`([^`]+)`/g, "$1").replace(/\s+/g, " ").trim();
  return cleaned.length > 90 ? `${cleaned.slice(0, 87)}...` : cleaned;
}
