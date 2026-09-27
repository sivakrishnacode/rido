import { createHmac } from 'node:crypto';

import { IdentityStatus } from '../../generated/prisma/enums.js';
import { isValidDiditSignature, summarizeDecision, toIdentityStatus } from './didit.js';

const SECRET = 'whsec_test';
const NOW = 1_774_970_000;
const hmac = (data: string): string => createHmac('sha256', SECRET).update(data).digest('hex');

describe('isValidDiditSignature', () => {
  const body = { status: 'Approved', session_id: 's-1', decision: { id_verifications: [{ full_name: 'Murugan Selvam', score: 0.98 }] }, event_id: 'e-1' };
  // Didit signs sorted-key, compact, Unicode-preserved JSON.
  const canonical = '{"decision":{"id_verifications":[{"full_name":"Murugan Selvam","score":0.98}]},"event_id":"e-1","session_id":"s-1","status":"Approved"}';

  it('accepts a valid X-Signature-V2 regardless of key order', () => {
    expect(isValidDiditSignature({ body, signatureV2: hmac(canonical), timestamp: String(NOW), secret: SECRET, nowS: NOW })).toBe(true);
  });

  it('keeps non-ASCII characters as-is', () => {
    const tamil = { name: 'முருகன்' };
    expect(isValidDiditSignature({ body: tamil, signatureV2: hmac('{"name":"முருகன்"}'), timestamp: String(NOW), secret: SECRET, nowS: NOW })).toBe(true);
  });

  it('falls back to X-Signature over the raw body', () => {
    const raw = Buffer.from('{"b":1,"a":2}');
    expect(isValidDiditSignature({ body: { b: 1, a: 2 }, rawBody: raw, signature: hmac(raw.toString()), timestamp: String(NOW), secret: SECRET, nowS: NOW })).toBe(true);
  });

  it('rejects a wrong signature, a stale timestamp or a missing secret', () => {
    expect(isValidDiditSignature({ body, signatureV2: hmac('{}'), timestamp: String(NOW), secret: SECRET, nowS: NOW })).toBe(false);
    expect(isValidDiditSignature({ body, signatureV2: hmac(canonical), timestamp: String(NOW - 301), secret: SECRET, nowS: NOW })).toBe(false);
    expect(isValidDiditSignature({ body, signatureV2: hmac(canonical), timestamp: String(NOW), secret: '', nowS: NOW })).toBe(false);
    expect(isValidDiditSignature({ body, timestamp: String(NOW), secret: SECRET, nowS: NOW })).toBe(false);
  });
});

describe('toIdentityStatus', () => {
  it('maps every Didit status', () => {
    expect(toIdentityStatus('Approved')).toBe(IdentityStatus.APPROVED);
    expect(toIdentityStatus('Declined')).toBe(IdentityStatus.DECLINED);
    expect(toIdentityStatus('In Review')).toBe(IdentityStatus.IN_REVIEW);
    expect(toIdentityStatus('In Progress')).toBe(IdentityStatus.IN_PROGRESS);
    expect(toIdentityStatus('Resubmitted')).toBe(IdentityStatus.IN_PROGRESS);
    for (const s of ['Not Started', 'Expired', 'Abandoned', 'Kyc Expired']) expect(toIdentityStatus(s)).toBe(IdentityStatus.NOT_STARTED);
  });
});

describe('summarizeDecision', () => {
  it('keeps only the last 4 characters of the document number and real warnings', () => {
    const summary = summarizeDecision({
      status: 'Declined',
      id_verifications: [
        {
          document_type: 'Driving License',
          document_number: 'TN37 20190012345',
          first_name: 'Murugan',
          last_name: 'Selvam',
          date_of_birth: '1990-04-12',
          warnings: [{ short_description: 'QR not detected', log_type: 'information' }, { short_description: 'Document has expired', log_type: 'error' }],
        },
      ],
      face_matches: [{ status: 'Declined', warnings: [{ risk: 'LOW_FACE_MATCH_SIMILARITY', log_type: 'error' }] }],
    });
    expect(summary).toEqual({
      documentType: 'Driving License',
      documentLast4: '2345',
      documents: [{ type: 'Driving License', last4: '2345' }],
      hasDrivingLicence: true,
      fullName: 'Murugan Selvam',
      dateOfBirth: '1990-04-12',
      warnings: ['Document has expired', 'LOW_FACE_MATCH_SIMILARITY'],
    });
  });

  it('handles an empty decision', () => {
    expect(summarizeDecision(undefined)).toEqual({
      documentType: null,
      documentLast4: null,
      documents: [],
      hasDrivingLicence: false,
      fullName: null,
      dateOfBirth: null,
      warnings: [],
    });
  });

  it('prefers the licence when a driver scans licence + Aadhaar', () => {
    const summary = summarizeDecision({
      id_verifications: [
        { document_type: 'Driving License', document_number: 'TN3820190012345', full_name: 'Murugan Selvam' },
        { document_type: 'Identity Card', document_number: '1234 5678 9012', full_name: 'Murugan Selvam' },
      ],
    });
    expect(summary.documentType).toBe('Driving License');
    expect(summary.documentLast4).toBe('2345');
    expect(summary.documents).toEqual([
      { type: 'Driving License', last4: '2345' },
      { type: 'Identity Card', last4: '9012' },
    ]);
  });
});
