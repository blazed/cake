/**
 * Filesystem-safety helpers for persisted workflow files.
 *
 * Saved-workflow names (which can originate from a workflow's `meta.name`) and
 * run IDs are interpolated into filenames. Without validation, a `../` name
 * could read/write/delete JSON outside the intended directory. These guards
 * reject unsafe names and assert that a resolved path stays under its base dir.
 */

import { resolve, sep } from "node:path";
import { WorkflowError, WorkflowErrorCode } from "./errors.ts";

/** A single path segment: starts alphanumeric, then alphanumerics/`._-`, no `..`, ≤128 chars. */
const SAFE_NAME = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;

/** Validate a name/ID used as a filename. Throws (non-recoverable) when unsafe. */
export function assertSafeName(name: string): string {
  if (typeof name !== "string" || name.length === 0 || name.length > 128 || name.includes("..") || !SAFE_NAME.test(name)) {
    throw new WorkflowError(
      `unsafe workflow name/id: ${JSON.stringify(name)}`,
      WorkflowErrorCode.SCRIPT_VALIDATION_ERROR,
      { recoverable: false },
    );
  }
  return name;
}

/** Assert that `fullPath` resolves to a location inside `baseDir`. Returns the resolved path. */
export function assertInside(baseDir: string, fullPath: string): string {
  const base = resolve(baseDir);
  const full = resolve(fullPath);
  if (full !== base && !full.startsWith(base + sep)) {
    throw new WorkflowError(
      `path escapes ${base}: ${full}`,
      WorkflowErrorCode.PERSISTENCE_ERROR,
      { recoverable: false },
    );
  }
  return full;
}
