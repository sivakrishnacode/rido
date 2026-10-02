/** Readable lines for a person's admin history (their audit rows), shown on the driver and account pages. */

const DOC: Record<string, string> = {
  VEHICLE_RC: 'Vehicle RC',
  INSURANCE: 'Insurance',
  DRIVING_LICENCE: 'Driving licence',
  AADHAAR: 'Aadhaar',
  POLICE_VERIFICATION: 'Police verification',
};

const STATUS: Record<string, string> = { APPROVED: 'Approved', PENDING: 'Moved to pending', ON_HOLD: 'Put on hold', REJECTED: 'Rejected' };

const PROFILE_FIELD: Record<string, string> = {
  vehicleKind: 'vehicle',
  vehicleModel: 'model',
  vehicleColor: 'colour',
  plate: 'plate',
  upiId: 'UPI ID',
  workType: 'work type',
  name: 'name',
  email: 'email',
};

function words(value: string): string {
  const s = value.toLowerCase().replace(/_/g, ' ');
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function withReason(text: string, reason: unknown): string {
  return typeof reason === 'string' && reason.trim() ? `${text}: ${reason.trim()}` : text;
}

/** "PATCH /v1/admin/drivers/:id" + {body} → "Put on hold: Insurance expired". Unknown actions fall back to the route. */
export function describeAudit(action: string, data: unknown): string {
  const body = ((data as { body?: Record<string, unknown> } | null)?.body ?? {}) as Record<string, unknown>;
  const params = ((data as { params?: Record<string, string> } | null)?.params ?? {}) as Record<string, string>;
  const [method, route = ''] = action.split(' ');
  const path = route.replace(/^\/?v1\/admin\//, '');
  const is = (m: string, p: string) => method === m && path === p;

  if (is('PATCH', 'drivers/:id') && typeof body.status === 'string') return withReason(STATUS[body.status] ?? `Status: ${words(body.status)}`, body.reason);
  if (is('POST', 'drivers/approve')) return 'Approved (bulk approval)';
  if (is('POST', 'drivers/:id/documents/:type')) {
    const doc = DOC[params.type ?? ''] ?? 'Document';
    return body.status === 'VERIFIED' ? `${doc} verified` : withReason(`${doc} rejected`, body.reason);
  }
  if (is('POST', 'drivers/:id/photo')) return body.isApproved ? 'Profile photo approved' : withReason('Profile photo rejected', body.reason);
  if (is('POST', 'drivers/:id/lift-block')) return 'Cancellation pause lifted';
  if (is('POST', 'drivers/:id/offline')) return 'Taken offline by an admin';
  if (is('PATCH', 'drivers/:id/profile') || (is('PATCH', 'users/:id') && (body.name !== undefined || body.email !== undefined) && body.role === undefined && body.isBlocked === undefined)) {
    const fields = Object.keys(body).map((k) => PROFILE_FIELD[k] ?? k);
    return fields.length ? `Edited ${fields.join(', ')}` : 'Edited details';
  }
  if (is('PATCH', 'users/:id')) {
    if (body.isBlocked === true) return withReason('Blocked', body.blockedReason);
    if (body.isBlocked === false) return 'Unblocked';
    if (typeof body.role === 'string') return `Role changed to ${words(body.role).toLowerCase()}`;
  }
  if (is('POST', 'users/:id/message')) return typeof body.title === 'string' ? `Push sent: “${body.title}”` : 'Push sent';
  if (is('POST', 'users/:id/notes')) return 'Note added';
  // The driver changed their plate in the app (a new vehicle: the RC is uploaded again, an approved driver re-checked).
  if (action === 'PATCH /v1/drivers/me' && typeof body.plate === 'string') return `New plate ${body.plate} in the app: RC to upload again`;
  return action;
}
