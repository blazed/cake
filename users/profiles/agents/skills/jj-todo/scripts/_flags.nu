#!/usr/bin/env nu
# Shared canonical list of [task:*] flags used across the workflow scripts.
# This file is a reference/helper for Nushell users; executable scripts keep the
# same constants inline so they can be invoked from any working directory.

export const TASK_FLAGS = [draft todo wip blocked standby untested review done]
export const TASK_FLAGS_BLOCKING = [draft todo wip blocked]

export def detect-task-flag [desc: string] {
  $TASK_FLAGS
  | where {|flag| $desc | str starts-with $"[task:($flag)]" }
  | first
  | default ""
}

export def is-valid-flag [candidate: string] {
  $candidate in $TASK_FLAGS
}

export def is-blocking-flag [candidate: string] {
  $candidate in $TASK_FLAGS_BLOCKING
}
