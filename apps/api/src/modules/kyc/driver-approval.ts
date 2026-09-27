import { DriverStatus, IdentityStatus, KycDocType, KycStatus } from '../../generated/prisma/enums.js';

/** Documents a driver still uploads for admin review. Identity (licence + selfie) is checked by Didit instead. */
export const REQUIRED_DOCS: readonly KycDocType[] = [KycDocType.VEHICLE_RC, KycDocType.INSURANCE];

/**
 * A driver's status from their documents and identity check. APPROVED needs every required document verified
 * and (when Didit is set up) an approved identity; any rejection → REJECTED; otherwise PENDING. ON_HOLD is an
 * admin decision and never changes here, and already-approved drivers stay approved until something is rejected.
 */
export function nextDriverStatus(params: {
  current: DriverStatus;
  docs: readonly { type: KycDocType; status: KycStatus }[];
  identity: IdentityStatus;
  isIdentityRequired: boolean;
}): DriverStatus {
  if (params.current === DriverStatus.ON_HOLD) return params.current;
  const required = params.docs.filter((d) => REQUIRED_DOCS.includes(d.type));
  const isDocsVerified = REQUIRED_DOCS.every((t) => required.some((d) => d.type === t && d.status === KycStatus.VERIFIED));
  const isIdentityOk = !params.isIdentityRequired || params.identity === IdentityStatus.APPROVED;
  const isRejected =
    required.some((d) => d.status === KycStatus.REJECTED) || (params.isIdentityRequired && params.identity === IdentityStatus.DECLINED);
  if (isRejected) return DriverStatus.REJECTED;
  if (isDocsVerified && isIdentityOk) return DriverStatus.APPROVED;
  return params.current === DriverStatus.APPROVED ? DriverStatus.APPROVED : DriverStatus.PENDING;
}
