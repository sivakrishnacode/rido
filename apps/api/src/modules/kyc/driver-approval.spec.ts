import { DriverStatus, IdentityStatus, KycDocType, KycStatus } from '../../generated/prisma/enums.js';
import { approvalChecklist, nextDriverStatus } from './driver-approval.js';

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

  it('leaves a ready driver pending for an admin when auto-approval is off', () => {
    const ready = { docs: docs(VERIFIED, VERIFIED), identity: IdentityStatus.APPROVED, isIdentityRequired: true, isAutoApprove: false };
    expect(nextDriverStatus({ current: DriverStatus.PENDING, ...ready })).toBe(DriverStatus.PENDING);
    // Approved by an admin: stays approved; a rejection still rejects.
    expect(nextDriverStatus({ current: DriverStatus.APPROVED, ...ready })).toBe(DriverStatus.APPROVED);
    expect(nextDriverStatus({ current: DriverStatus.PENDING, ...ready, docs: docs(REJECTED, VERIFIED) })).toBe(DriverStatus.REJECTED);
  });
});

describe('approvalChecklist', () => {
  it('lists each document and the identity check with its state', () => {
    const c = approvalChecklist({ docs: docs(VERIFIED, UNDER_REVIEW), identity: IdentityStatus.IN_REVIEW, isIdentityRequired: true });
    expect(c.checks).toEqual([
      { key: KycDocType.VEHICLE_RC, state: 'DONE' },
      { key: KycDocType.INSURANCE, state: 'REVIEW' },
      { key: 'IDENTITY', state: 'REVIEW' },
    ]);
    expect(c.isReady).toBe(false);
    expect(c.isRejected).toBe(false);
  });

  it('skips identity without Didit and treats a missing row as to do', () => {
    const c = approvalChecklist({ docs: [{ type: KycDocType.VEHICLE_RC, status: VERIFIED }], identity: IdentityStatus.NOT_STARTED, isIdentityRequired: false });
    expect(c.checks.map((x) => x.state)).toEqual(['DONE', 'TODO']);
    expect(approvalChecklist({ docs: docs(VERIFIED, VERIFIED), identity: IdentityStatus.DECLINED, isIdentityRequired: false }).isReady).toBe(true);
    expect(approvalChecklist({ docs: docs(VERIFIED, VERIFIED), identity: IdentityStatus.DECLINED, isIdentityRequired: true }).isRejected).toBe(true);
  });
});
