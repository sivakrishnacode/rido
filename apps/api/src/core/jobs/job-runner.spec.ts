import { type ClaimedJob, type JobData, JobRunner, type JobStore, LEASE_MS, jobKey, leaseFor, parseJobKey, retryDelayMs } from './job-runner.js';

/** Same contract as the Redis store, in memory. */
class MemoryStore implements JobStore {
  readonly due = new Map<string, number>();
  readonly data = new Map<string, JobData>();
  async add(key: string, runAt: number, data: JobData): Promise<void> {
    this.due.set(key, runAt);
    this.data.set(key, data);
  }
  async remove(key: string): Promise<void> {
    this.due.delete(key);
    this.data.delete(key);
  }
  async runAt(key: string): Promise<number | null> {
    return this.due.get(key) ?? null;
  }
  async claim(now: number, limit: number, leaseMs: number): Promise<ClaimedJob[]> {
    const keys = [...this.due].filter(([, at]) => at <= now).sort((a, b) => a[1] - b[1]).slice(0, limit).map(([k]) => k);
    const lease = leaseFor(now, leaseMs);
    return keys.map((key) => {
      this.due.set(key, lease);
      return { key, data: this.data.get(key) ?? { p: null, a: 0 }, lease };
    });
  }
  async finish(key: string, lease: number): Promise<void> {
    if (this.due.get(key) === lease) await this.remove(key);
  }
  async retry(key: string, lease: number, runAt: number, data: JobData): Promise<void> {
    if (this.due.get(key) === lease) await this.add(key, runAt, data);
  }
}

describe('JobRunner', () => {
  const T0 = 1_000_000;

  it('runs a job once it is due, with its payload, then forgets it', async () => {
    const store = new MemoryStore();
    const runner = new JobRunner(store);
    const seen: unknown[] = [];
    runner.register<{ driverId: string }>('offer.expire', async (job) => void seen.push([job.id, job.payload, job.attempt]));
    await runner.schedule('offer.expire', 'trip1', T0 + 15_000, { driverId: 'd1' });

    expect(await runner.runDue(T0 + 14_999)).toBe(0);
    expect(await runner.runDue(T0 + 15_000)).toBe(1);
    expect(seen).toEqual([['trip1', { driverId: 'd1' }, 1]]);
    expect(await runner.scheduledAt('offer.expire', 'trip1')).toBeNull();
    expect(await runner.runDue(T0 + 99_999)).toBe(0);
  });

  it('scheduling the same kind and id again replaces the pending run; cancel drops it', async () => {
    const store = new MemoryStore();
    const runner = new JobRunner(store);
    let runs = 0;
    runner.register('x', async () => void runs++);
    await runner.schedule('x', 'a', T0);
    await runner.schedule('x', 'a', T0 + 5_000);
    expect(await runner.runDue(T0)).toBe(0);
    await runner.cancel('x', 'a');
    expect(await runner.runDue(T0 + 10_000)).toBe(0);
    expect(runs).toBe(0);
  });

  it('keeps a job the handler schedules again for itself', async () => {
    const store = new MemoryStore();
    const runner = new JobRunner(store);
    runner.register('check', async (job) => runner.schedule('check', job.id, T0 + 60_000));
    await runner.schedule('check', 't', T0);
    await runner.runDue(T0);
    expect(await runner.scheduledAt('check', 't')).toBe(T0 + 60_000);
  });

  it('retries a failing handler with backoff, then drops it after maxAttempts', async () => {
    const store = new MemoryStore();
    const runner = new JobRunner(store);
    const attempts: number[] = [];
    runner.register(
      'flaky',
      async (job) => {
        attempts.push(job.attempt);
        throw new Error('boom');
      },
      { maxAttempts: 3, backoffMs: 1_000 },
    );
    await runner.schedule('flaky', 'j', T0);
    await runner.runDue(T0);
    expect(await runner.scheduledAt('flaky', 'j')).toBe(T0 + 1_000);
    await runner.runDue(T0 + 1_000);
    expect(await runner.scheduledAt('flaky', 'j')).toBe(T0 + 1_000 + 2_000);
    await runner.runDue(T0 + 3_000);
    expect(attempts).toEqual([1, 2, 3]);
    expect(await runner.scheduledAt('flaky', 'j')).toBeNull();
  });

  it('leases a claimed job so a crashed run comes back after LEASE_MS', async () => {
    const store = new MemoryStore();
    await store.add(jobKey('x', 'a'), T0, { p: null, a: 0 });
    expect(await store.claim(T0, 10, LEASE_MS)).toHaveLength(1);
    expect(await store.claim(T0 + 1, 10, LEASE_MS)).toHaveLength(0);
    expect(await store.claim(T0 + LEASE_MS + 1, 10, LEASE_MS)).toHaveLength(1);
  });

  it('drops jobs of an unknown kind and splits keys on the first bar', async () => {
    const store = new MemoryStore();
    const runner = new JobRunner(store);
    await runner.schedule('gone', 'a|b', T0);
    expect(await runner.runDue(T0)).toBe(1);
    expect(store.due.size).toBe(0);
    expect(parseJobKey(jobKey('k', 'a|b'))).toEqual({ kind: 'k', id: 'a|b' });
    expect(retryDelayMs(3, 500)).toBe(2_000);
    expect(() => runner.register('a|b', async () => undefined)).toThrow();
  });
});
