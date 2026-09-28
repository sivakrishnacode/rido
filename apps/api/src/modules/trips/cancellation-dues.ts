import { CancelFault } from '../../generated/prisma/enums.js';
import type { CancelSignals, FaultVerdict } from './cancel-fault.js';

/**
 * The cancellation fee owed for one cancellation (0 = none): only while `cancellationFeeEnabled`, only when the
 * passenger was at fault after the driver had arrived and waited the free minutes. The fee is owed to that driver.
 */
export function cancellationDueAmount(p: { enabled: boolean; fee: number; verdict: FaultVerdict; signals: CancelSignals }): number {
  if (!p.enabled || p.fee <= 0) return 0;
  if (p.verdict.fault !== CancelFault.PASSENGER || !p.signals.hasDriver || !p.signals.isArrived) return 0;
  return (p.signals.waitedSec ?? 0) >= p.signals.freeWaitMin * 60 ? Math.floor(p.fee) : 0;
}

/** [fare] with its "Previous cancellation fee" line set to [fee] (replacing any earlier one); the total moves by it. */
export function withCancellationFee<T extends { total: number; previousCancellationFee?: number }>(fare: T, fee: number): T & { previousCancellationFee: number } {
  const was = fare.previousCancellationFee ?? 0;
  return { ...fare, previousCancellationFee: fee, total: fare.total - was + fee };
}
