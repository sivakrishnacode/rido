/** One candidate driver for a trip, with the road ETA to the pickup. */
export interface Candidate {
  readonly driverId: string;
  readonly etaMin: number;
}

/** A trip waiting in the current batch and its candidates. */
export interface BatchRequest {
  readonly tripId: string;
  /** Earlier bookings win ties. */
  readonly createdAt: Date;
  readonly candidates: readonly Candidate[];
}

/**
 * Assigns drivers across a whole batch (not one rider at a time): all (trip, driver) pairs are
 * sorted by ETA and each trip takes the fastest driver nobody else has taken yet. Each trip's
 * remaining candidates follow as fallbacks, with drivers promised to other trips moved last.
 * Returns the ordered offer queue per trip.
 */
export function assignBatch(requests: readonly BatchRequest[]): Map<string, string[]> {
  const pairs = requests
    .flatMap((r) => r.candidates.map((c) => ({ tripId: r.tripId, createdAt: r.createdAt.getTime(), ...c })))
    .sort((a, b) => a.etaMin - b.etaMin || a.createdAt - b.createdAt);
  const primary = new Map<string, string>();
  const takenDrivers = new Set<string>();
  for (const p of pairs) {
    if (primary.has(p.tripId) || takenDrivers.has(p.driverId)) continue;
    primary.set(p.tripId, p.driverId);
    takenDrivers.add(p.driverId);
  }
  const result = new Map<string, string[]>();
  for (const r of requests) {
    const first = primary.get(r.tripId);
    const rest = [...r.candidates].sort((a, b) => a.etaMin - b.etaMin).map((c) => c.driverId).filter((id) => id !== first);
    const free = rest.filter((id) => !takenDrivers.has(id));
    const promised = rest.filter((id) => takenDrivers.has(id));
    result.set(r.tripId, [...(first ? [first] : []), ...free, ...promised]);
  }
  return result;
}
