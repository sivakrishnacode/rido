import { Logger } from '@nestjs/common';

/** A job as a handler sees it. [attempt] starts at 1. */
export interface Job<P = unknown> {
  readonly kind: string;
  readonly id: string;
  readonly payload: P;
  readonly attempt: number;
}

export type JobHandler<P = unknown> = (job: Job<P>) => Promise<void>;

export interface JobOptions {
  /** Runs (first try included) before a failing job is dropped. Default 3. */
  readonly maxAttempts?: number;
  /** Delay before retry n is backoffMs × 2^(n-1). Default 5 s. */
  readonly backoffMs?: number;
}

/** Stored with each job: its payload and how many runs have failed. */
export interface JobData {
  readonly p: unknown;
  readonly a: number;
}

/** A due job taken by [JobStore.claim]: it is leased (hidden) until [lease]; finish or retry it with that lease. */
export interface ClaimedJob {
  readonly key: string;
  readonly data: JobData;
  readonly lease: number;
}

/**
 * Where jobs live (Redis in the app, memory in unit tests). One entry per key: scheduling a key again replaces it.
 * [claim] must be atomic across instances; [finish] and [retry] only act while the job still holds that lease (a
 * handler that schedules its own key again keeps the new entry).
 */
export interface JobStore {
  add(key: string, runAt: number, data: JobData): Promise<void>;
  remove(key: string): Promise<void>;
  runAt(key: string): Promise<number | null>;
  claim(now: number, limit: number, leaseMs: number): Promise<ClaimedJob[]>;
  finish(key: string, lease: number): Promise<void>;
  retry(key: string, lease: number, runAt: number, data: JobData): Promise<void>;
}

/** `kind|id`: ids may contain anything but the kind must not contain `|`. */
export const jobKey = (kind: string, id: string): string => `${kind}|${id}`;

export function parseJobKey(key: string): { kind: string; id: string } {
  const i = key.indexOf('|');
  return { kind: key.slice(0, i), id: key.slice(i + 1) };
}

/** Delay before the retry that follows failed run [attempt] (1-based). */
export const retryDelayMs = (attempt: number, backoffMs: number): number => backoffMs * 2 ** (attempt - 1);

/** A claimed job is hidden this long; a process that dies mid-run lets it run again after that. */
export const LEASE_MS = 60_000;

/**
 * The score a job claimed at [now] is leased to. Half a millisecond off the whole-ms run times, so [JobStore.finish]
 * can tell "still my lease" from "the handler scheduled this job again".
 */
export const leaseFor = (now: number, leaseMs: number): number => Math.floor(now) + leaseMs + 0.5;
const BATCH = 100;

/**
 * Tiny durable scheduler: jobs are (kind, id) → run time + payload in a [JobStore]; [runDue] claims the due ones
 * and calls the handler registered for their kind. A throwing handler is logged and retried with backoff up to
 * `maxAttempts`, then dropped.
 */
export class JobRunner {
  protected readonly logger = new Logger('Jobs');
  private readonly handlers = new Map<string, { run: JobHandler; maxAttempts: number; backoffMs: number }>();

  constructor(private readonly store: JobStore) {}

  register<P>(kind: string, handler: JobHandler<P>, opts: JobOptions = {}): void {
    if (kind.includes('|')) throw new Error(`Job kind "${kind}" must not contain "|"`);
    this.handlers.set(kind, { run: handler as JobHandler, maxAttempts: opts.maxAttempts ?? 3, backoffMs: opts.backoffMs ?? 5_000 });
  }

  /** Runs [kind]/[id] at [runAt] (a Date or epoch ms), replacing any pending run of it. */
  schedule(kind: string, id: string, runAt: Date | number, payload?: unknown): Promise<void> {
    // Whole milliseconds: leases end in .5 (see [leaseFor]), so a job scheduled again never looks like its lease.
    return this.store.add(jobKey(kind, id), Math.round(typeof runAt === 'number' ? runAt : runAt.getTime()), { p: payload ?? null, a: 0 });
  }

  /** Drops the pending run of [kind]/[id], if any. */
  cancel(kind: string, id: string): Promise<void> {
    return this.store.remove(jobKey(kind, id));
  }

  /** When [kind]/[id] is due (epoch ms), or null when nothing is scheduled. */
  scheduledAt(kind: string, id: string): Promise<number | null> {
    return this.store.runAt(jobKey(kind, id));
  }

  /** Claims and runs every job due at [now]. Returns how many ran (successfully or not). */
  async runDue(now = Date.now()): Promise<number> {
    let total = 0;
    for (;;) {
      const claimed = await this.store.claim(now, BATCH, LEASE_MS);
      if (claimed.length === 0) return total;
      await Promise.all(claimed.map((c) => this.runOne(c, now)));
      total += claimed.length;
      if (claimed.length < BATCH) return total;
    }
  }

  private async runOne(c: ClaimedJob, now: number): Promise<void> {
    const { kind, id } = parseJobKey(c.key);
    const handler = this.handlers.get(kind);
    if (!handler) {
      this.logger.warn(`No handler for job ${c.key}; dropped`);
      return this.store.finish(c.key, c.lease);
    }
    const attempt = c.data.a + 1;
    try {
      await handler.run({ kind, id, payload: c.data.p, attempt });
      await this.store.finish(c.key, c.lease);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (attempt >= handler.maxAttempts) {
        this.logger.error(`Job ${c.key} failed (attempt ${attempt}/${handler.maxAttempts}), dropped: ${msg}`);
        return this.store.finish(c.key, c.lease);
      }
      this.logger.warn(`Job ${c.key} failed (attempt ${attempt}/${handler.maxAttempts}), retrying: ${msg}`);
      await this.store.retry(c.key, c.lease, Math.round(now + retryDelayMs(attempt, handler.backoffMs)), { p: c.data.p, a: attempt });
    }
  }
}
