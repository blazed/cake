export interface QuotaWindowSnapshot {
  usedPercent: number;
  windowDurationMins: number | null;
  resetsAt: number | null;
}

export interface QuotaSnapshot {
  limitId: string | null;
  limitName: string | null;
  primary: QuotaWindowSnapshot | null;
  secondary: QuotaWindowSnapshot | null;
  tertiary?: QuotaWindowSnapshot | null;
}

export interface QuotaTracker {
  setEnabled: (enabled: boolean) => void;
  getSnapshot: () => QuotaSnapshot | null;
  dispose: () => void;
}

export interface QuotaTrackerOptions {
  refreshIntervalMs?: number;
  now?: () => number;
  setInterval?: typeof globalThis.setInterval;
  clearInterval?: typeof globalThis.clearInterval;
}

export function createQuotaTracker(
  readSnapshot: (signal: AbortSignal) => Promise<QuotaSnapshot | null>,
  onUpdate: () => void,
  options: QuotaTrackerOptions = {},
): QuotaTracker {
  const refreshIntervalMs = options.refreshIntervalMs ?? 60_000;
  const now = options.now ?? Date.now;
  const startTimer = options.setInterval ?? globalThis.setInterval;
  const stopTimer = options.clearInterval ?? globalThis.clearInterval;

  let enabled = false;
  let snapshot: QuotaSnapshot | null = null;
  let lastAttemptAt: number | null = null;
  let activeRefresh: { controller: AbortController } | null = null;
  let interval: ReturnType<typeof setInterval> | null = null;
  let disposed = false;

  const abortRefresh = (): void => {
    if (!activeRefresh) return;
    activeRefresh.controller.abort();
    activeRefresh = null;
    lastAttemptAt = null;
  };

  const refresh = async (): Promise<void> => {
    if (disposed || !enabled || activeRefresh) return;
    lastAttemptAt = now();
    const request = { controller: new AbortController() };
    activeRefresh = request;

    try {
      const next = await readSnapshot(request.controller.signal);
      if (disposed || request.controller.signal.aborted || activeRefresh !== request) return;
      const previousJson = snapshot ? JSON.stringify(snapshot) : null;
      const nextJson = next ? JSON.stringify(next) : null;
      snapshot = next;
      if (previousJson !== nextJson) onUpdate();
    } catch {
      // Failed attempts remain negative-cached until the next refresh interval.
    } finally {
      if (activeRefresh === request) activeRefresh = null;
    }
  };

  const stopInterval = (): void => {
    if (interval !== null) {
      stopTimer(interval);
      interval = null;
    }
  };

  const startInterval = (): void => {
    if (interval !== null) return;
    interval = startTimer(() => {
      void refresh();
    }, refreshIntervalMs);
  };

  return {
    setEnabled(nextEnabled: boolean): void {
      if (disposed) return;
      enabled = nextEnabled;
      if (!enabled) {
        stopInterval();
        abortRefresh();
        return;
      }

      startInterval();
      if (lastAttemptAt === null || now() - lastAttemptAt >= refreshIntervalMs) {
        void refresh();
      }
    },
    getSnapshot(): QuotaSnapshot | null {
      return snapshot;
    },
    dispose(): void {
      disposed = true;
      enabled = false;
      stopInterval();
      abortRefresh();
    },
  };
}
