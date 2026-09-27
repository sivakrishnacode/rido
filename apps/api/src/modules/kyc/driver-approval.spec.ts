import { DriverStatus, IdentityStatus, KycDocType, KycStatus } from '../../generated/prisma/enums.js';
import { nextDriverStatus } from './driver-approval.js';

const docs = (rc: KycStatus, ins: KycStatus) => [
  { type: KycDocType.VEHICLE_RC, status: rc },
  { type: KycDocType.INSURANCE, status: ins },
  // Old rows no longer count (police verification isn't needed).
  { type: KycDocType.POLICE_VERIFICATION, status: KycStatus.NOT_UPLOADED },
];
const { VERIFIED, UNDER_REVIEW, REJECTED } = KycStatus;

describe('nextDriverStatus', () => {
  it('approves once RC + insurance are verified and identity is approved', () => {
    expect(nextDriverStatus({ current: DriverStatus.PENDING, docs: docs(VERIFIED, VERIFIED), identity: IdentityStatus.APPROVED, isIdentityRequired: true })).toBe(DriverStatus.APPROVED);
  });

  it('waits for the identity check', () => {
    expect(nextDriverStatus({ current: DriverStatus.PENDING, docs: docs(VERIFIED, VERIFIED), identity: IdentityStatus.IN_REVIEW, isIdentityRequired: true })).toBe(DriverStatus.PENDING);
  });

  it('does not need identity when Didit is not set up', () => {
    expect(nextDriverStatus({ current: DriverStatus.PENDING, docs: docs(VERIFIED, VERIFIED), identity: IdentityStatus.NOT_STARTED, isIdentityRequired: false })).toBe(DriverStatus.APPROVED);
  });

  it('rejects on a rejected document or a declined identity', () => {
    expect(nextDriverStatus({ current: DriverStatus.PENDING, docs: docs(REJECTED, VERIFIED), identity: IdentityStatus.APPROVED, isIdentityRequired: true })).toBe(DriverStatus.REJECTED);
    expect(nextDriverStatus({ current: DriverStatus.APPROVED, docs: docs(VERIFIED, VERIFIED), identity: IdentityStatus.DECLINED, isIdentityRequired: true })).toBe(DriverStatus.REJECTED);
  });

  it('goes back to pending after a re-upload, keeps approved drivers and never touches ON_HOLD', () => {
    expect(nextDriverStatus({ current: DriverStatus.REJECTED, docs: docs(UNDER_REVIEW, VERIFIED), identity: IdentityStatus.APPROVED, isIdentityRequired: true })).toBe(DriverStatus.PENDING);
    expect(nextDriverStatus({ current: DriverStatus.APPROVED, docs: docs(VERIFIED, VERIFIED), identity: IdentityStatus.NOT_STARTED, isIdentityRequired: true })).toBe(DriverStatus.APPROVED);
    expect(nextDriverStatus({ current: DriverStatus.ON_HOLD, docs: docs(VERIFIED, VERIFIED), identity: IdentityStatus.APPROVED, isIdentityRequired: true })).toBe(DriverStatus.ON_HOLD);
  });
});
