import type { Redis } from 'ioredis';

import { type ClaimedJob, type JobData, type JobStore, leaseFor } from './job-runner.js';

const DUE = 'jobs:due';
const DATA = 'jobs:data';

/** Takes up to ARGV[2] members due by ARGV[1] and leases them (re-scores them to ARGV[3]); returns member, data pairs. */
const CLAIM = `local ids = redis.call('zrangebyscore', KEYS[1], '-inf', ARGV[1], 'LIMIT', 0, tonumber(ARGV[2]))
local out = {}
for _, m in ipairs(ids) do
  redis.call('zadd', KEYS[1], ARGV[3], m)
  out[#out + 1] = m
  out[#out + 1] = redis.call('hget', KEYS[2], m) or ''
end
return out`;

/** Removes ARGV[1] while it still holds lease ARGV[2]. */
const FINISH = `local s = redis.call('zscore', KEYS[1], ARGV[1])
if s and tonumber(s) == tonumber(ARGV[2]) then
  redis.call('zrem', KEYS[1], ARGV[1])
  redis.call('hdel', KEYS[2], ARGV[1])
  return 1
end
return 0`;

/** Re-schedules ARGV[1] to ARGV[3] with data ARGV[4] while it still holds lease ARGV[2]. */
const RETRY = `local s = redis.call('zscore', KEYS[1], ARGV[1])
if s and tonumber(s) == tonumber(ARGV[2]) then
  redis.call('zadd', KEYS[1], ARGV[3], ARGV[1])
  redis.call('hset', KEYS[2], ARGV[1], ARGV[4])
  return 1
end
return 0`;

/**
 * Jobs in Redis (like Namma Yatri's scheduler): a sorted set `jobs:due` (member `kind|id`, score = run time in epoch
 * ms) and a hash `jobs:data` with each job's payload. A claim leases the job by moving its score [leaseMs] into the
 * future, so a crash mid-run makes it due again instead of losing it; the Lua scripts keep claims atomic across API
 * instances.
 */
export class RedisJobStore implements JobStore {
  constructor(private readonly redis: Redis) {}

  async add(key: string, runAt: number, data: JobData): Promise<void> {
    await this.redis.multi().zadd(DUE, runAt, key).hset(DATA, key, JSON.stringify(data)).exec();
  }

  async remove(key: string): Promise<void> {
    await this.redis.multi().zrem(DUE, key).hdel(DATA, key).exec();
  }

  async runAt(key: string): Promise<number | null> {
    const s = await this.redis.zscore(DUE, key);
    return s === null ? null : Number(s);
  }

  async claim(now: number, limit: number, leaseMs: number): Promise<ClaimedJob[]> {
    const lease = leaseFor(now, leaseMs);
    const flat = (await this.redis.eval(CLAIM, 2, DUE, DATA, now, limit, lease)) as string[];
    const out: ClaimedJob[] = [];
    for (let i = 0; i < flat.length; i += 2) out.push({ key: flat[i], data: parse(flat[i + 1]), lease });
    return out;
  }

  async finish(key: string, lease: number): Promise<void> {
    await this.redis.eval(FINISH, 2, DUE, DATA, key, lease);
  }

  async retry(key: string, lease: number, runAt: number, data: JobData): Promise<void> {
    await this.redis.eval(RETRY, 2, DUE, DATA, key, lease, runAt, JSON.stringify(data));
  }
}

function parse(raw: string): JobData {
  try {
    const d = JSON.parse(raw) as Partial<JobData>;
    return { p: d.p ?? null, a: d.a ?? 0 };
  } catch {
    return { p: null, a: 0 };
  }
}
