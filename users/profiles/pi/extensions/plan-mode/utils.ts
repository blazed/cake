import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join, normalize, resolve } from "node:path";

export interface PendingFreshImplementation {
  planFilePath: string;
  requestedAt: string;
}

export interface PlanModeState {
  active: boolean;
  planFilePath: string | null;
  planSlug: string | null;
  lastApprovedPlanFilePath: string | null;
  previousToolNames: string[] | null;
  pendingFreshImplementation: PendingFreshImplementation | null;
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

export const DEFAULT_PLAN_ROOT = join(homedir(), ".pi", "agent", "plans");

export function createInitialState(): PlanModeState {
  return {
    active: false,
    planFilePath: null,
    planSlug: null,
    lastApprovedPlanFilePath: null,
    previousToolNames: null,
    pendingFreshImplementation: null,
  };
}

export function sanitizePlanModeState(candidate: Partial<PlanModeState> | null | undefined): PlanModeState {
  const initial = createInitialState();
  if (!candidate || typeof candidate !== "object") return initial;

  return {
    active: candidate.active === true,
    planFilePath: typeof candidate.planFilePath === "string" ? candidate.planFilePath : null,
    planSlug: typeof candidate.planSlug === "string" ? candidate.planSlug : null,
    lastApprovedPlanFilePath:
      typeof candidate.lastApprovedPlanFilePath === "string" ? candidate.lastApprovedPlanFilePath : null,
    previousToolNames: Array.isArray(candidate.previousToolNames)
      ? candidate.previousToolNames.filter((name): name is string => typeof name === "string")
      : null,
    pendingFreshImplementation: sanitizePendingFreshImplementation(candidate.pendingFreshImplementation),
  };
}

function sanitizePendingFreshImplementation(candidate: unknown): PendingFreshImplementation | null {
  if (!candidate || typeof candidate !== "object") return null;
  const value = candidate as Partial<PendingFreshImplementation>;
  if (typeof value.planFilePath !== "string") return null;
  return {
    planFilePath: value.planFilePath,
    requestedAt: typeof value.requestedAt === "string" ? value.requestedAt : new Date(0).toISOString(),
  };
}

export function slugify(value: string): string {
  return (
    value
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 48) || "workspace"
  );
}

function generateSlug(random: () => number = Math.random): string {
  const adj = ADJECTIVES[Math.floor(random() * ADJECTIVES.length)] ?? "clear";
  const noun = NOUNS[Math.floor(random() * NOUNS.length)] ?? "path";
  return `${adj}-${noun}`;
}

function ensurePlanDir(cwd: string, root = DEFAULT_PLAN_ROOT): string {
  const dir = join(root, slugify(basename(cwd) || cwd));
  mkdirSync(dir, { recursive: true });
  return dir;
}

export function generateUniquePlanPath(
  cwd: string,
  root = DEFAULT_PLAN_ROOT,
  random: () => number = Math.random,
): { slug: string; path: string } {
  const dir = ensurePlanDir(cwd, root);
  for (let i = 0; i < 10; i++) {
    const slug = generateSlug(random);
    const path = join(dir, `${slug}.md`);
    if (!existsSync(path)) return { slug, path };
  }

  const slug = `${generateSlug(random)}-${Date.now()}`;
  return { slug, path: join(dir, `${slug}.md`) };
}

export function readPlan(path: string | null | undefined): string | null {
  if (!path) return null;
  try {
    return readFileSync(path, "utf-8");
  } catch {
    return null;
  }
}

export function writePlan(path: string, content: string): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, content, "utf-8");
}

export function normalizePlanTitle(title: string | null | undefined): string {
  const normalized = (title ?? "")
    .replace(/^#+\s*/, "")
    .replace(/^Plan:\s*/i, "")
    .replace(/[\r\n\t]+/g, " ")
    .replace(/[`*_#[\]()]/g, "")
    .replace(/\s+/g, " ")
    .trim();

  return (normalized || "Approved plan").slice(0, 80);
}

export function extractPlanTitle(content: string | null | undefined): string {
  if (!content) return "Approved plan";
  const explicitPlanTitle = content.match(/^#\s+Plan:\s*(.+)$/im)?.[1];
  if (explicitPlanTitle) return normalizePlanTitle(explicitPlanTitle);

  const firstHeading = content.match(/^#\s+(.+)$/m)?.[1];
  if (firstHeading) return normalizePlanTitle(firstHeading);

  const firstLine = content
    .split(/\r?\n/)
    .map((line) => line.trim())
    .find(Boolean);
  return normalizePlanTitle(firstLine);
}

export function resolvePlanTargetPath(
  targetPath: string | null | undefined,
  cwd: string,
  planFilePath: string | null | undefined,
): string | null {
  if (!targetPath || !planFilePath) return null;
  const cleanedTarget = stripPathPrefix(targetPath);
  const normalizedPlanPath = normalizeAbsolutePath(planFilePath);

  if (basename(cleanedTarget) === basename(normalizedPlanPath)) return normalizedPlanPath;
  return normalizeAbsolutePath(resolve(cwd, cleanedTarget));
}

export function isPlanFileTarget(
  targetPath: string | null | undefined,
  cwd: string,
  planFilePath: string | null | undefined,
): boolean {
  if (!planFilePath) return false;
  return resolvePlanTargetPath(targetPath, cwd, planFilePath) === normalizeAbsolutePath(planFilePath);
}

export function buildPlanFileSummary(plan: string | null | undefined, planFilePath: string | null | undefined): string {
  if (!planFilePath) return "Plan file: none";
  const content = plan ?? "";
  const trimmed = content.trim();
  const lineCount = trimmed ? content.split(/\r?\n/).length : 0;

  return [
    `Plan file: ${planFilePath}`,
    `Title: ${extractPlanTitle(content)}`,
    `Status: ${trimmed ? "present" : "empty or missing"}`,
    `Size: ${content.length} chars, ${lineCount} lines`,
  ].join("\n");
}

function stripPathPrefix(path: string): string {
  return path.startsWith("@") ? path.slice(1) : path;
}

function normalizeAbsolutePath(path: string): string {
  return normalize(resolve(path));
}
