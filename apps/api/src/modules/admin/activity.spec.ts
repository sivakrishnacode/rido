import { describeAudit } from './activity.js';

const row = (action: string, body: Record<string, unknown> = {}, params: Record<string, string> = {}) => describeAudit(action, { body, params });

describe('describeAudit', () => {
  it('describes driver decisions with their reason', () => {
    expect(row('PATCH /v1/admin/drivers/:id', { status: 'ON_HOLD', reason: 'Insurance expired' })).toBe('Put on hold: Insurance expired');
    expect(row('PATCH /v1/admin/drivers/:id', { status: 'APPROVED' })).toBe('Approved');
    expect(row('POST /v1/admin/drivers/approve', { ids: ['a'] })).toBe('Approved (bulk approval)');
    expect(row('POST /v1/admin/drivers/:id/lift-block')).toBe('Cancellation pause lifted');
  });

  it('describes document and photo reviews', () => {
    expect(row('POST /v1/admin/drivers/:id/documents/:type', { status: 'VERIFIED' }, { type: 'VEHICLE_RC' })).toBe('Vehicle RC verified');
    expect(row('POST /v1/admin/drivers/:id/documents/:type', { status: 'REJECTED', reason: 'Blurred' }, { type: 'INSURANCE' })).toBe('Insurance rejected: Blurred');
    expect(row('POST /v1/admin/drivers/:id/photo', { isApproved: false, reason: 'Face hidden' })).toBe('Profile photo rejected: Face hidden');
  });

  it('describes account changes, edits and messages', () => {
    expect(row('PATCH /v1/admin/users/:id', { isBlocked: true, blockedReason: 'Abuse' })).toBe('Blocked: Abuse');
    expect(row('PATCH /v1/admin/users/:id', { isBlocked: false })).toBe('Unblocked');
    expect(row('PATCH /v1/admin/users/:id', { role: 'ADMIN' })).toBe('Role changed to admin');
    expect(row('PATCH /v1/admin/users/:id', { name: 'Selvi', email: 'a@b.in' })).toBe('Edited name, email');
    expect(row('PATCH /v1/admin/drivers/:id/profile', { plate: 'TN 38 AB 1234', upiId: 'x@ok' })).toBe('Edited plate, UPI ID');
    expect(row('POST /v1/admin/users/:id/message', { title: 'Please re-upload RC' })).toBe('Push sent: “Please re-upload RC”');
    expect(row('DELETE /v1/admin/something/:id')).toBe('DELETE /v1/admin/something/:id');
    expect(row('DELETE /v1/admin/users/:id')).toBe('Account deleted by an admin');
    expect(row('DELETE /v1/me')).toBe('Account deleted by the user');
    expect(row('PATCH /v1/drivers/me', { plate: 'TN 38 AB 1234' })).toBe('New plate TN 38 AB 1234 in the app: RC to upload again');
    expect(describeAudit('PATCH /v1/admin/users/:id', null)).toBe('PATCH /v1/admin/users/:id');
  });
});
