import { createHmac, timingSafeEqual } from 'node:crypto';

import { IdentityStatus } from '../../generated/prisma/enums.js';

/** Didit's exact session status strings (case-sensitive; note "Kyc Expired"). */
export type DiditStatus =
  | 'Not Started'
  | 'In Progress'
  | 'Approved'
  | 'Declined'
  | 'In Review'
  | 'Awaiting User'
  | 'Resubmitted'
  | 'Expired'
  | 'Abandoned'
  | 'Kyc Expired';

/** Didit status → ours. Expired / abandoned sessions count as "not started": the user can start a new one. */
export function toIdentityStatus(status: string): IdentityStatus {
  switch (status) {
    case 'Approved':
      return IdentityStatus.APPROVED;
    case 'Declined':
      return IdentityStatus.DECLINED;
    case 'In Review':
      return IdentityStatus.IN_REVIEW;
    case 'In Progress':
    case 'Resubmitted':
    case 'Awaiting User':
      return IdentityStatus.IN_PROGRESS;
    default:
      return IdentityStatus.NOT_STARTED;
  }
}

/** Recursively sorts object keys: Didit signs `sort_keys=True` compact JSON. */
function sortKeys(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((k) => [k, sortKeys((value as Record<string, unknown>)[k])]),
    );
  }
  return value;
}

const MAX_SKEW_S = 300;

function sameHex(expected: string, given: string): boolean {
  const a = Buffer.from(expected, 'utf8');
  const b = Buffer.from(given, 'utf8');
  return a.length === b.length && timingSafeEqual(a, b);
}

/**
 * Verifies a Didit webhook: `X-Timestamp` within 5 minutes, then `X-Signature-V2` (HMAC-SHA256 of the sorted,
 * compact, Unicode-preserved JSON) or, failing that, `X-Signature` (HMAC of the raw bytes).
 */
export function isValidDiditSignature(params: {
  body: unknown;
  rawBody?: Buffer;
  signatureV2?: string;
  signature?: string;
  timestamp?: string;
  secret: string;
  nowS?: number;
}): boolean {
  const ts = Number(params.timestamp);
  const now = params.nowS ?? Math.floor(Date.now() / 1000);
  if (!params.secret || !Number.isFinite(ts) || Math.abs(now - ts) > MAX_SKEW_S) return false;
  const hmac = (data: string | Buffer): string => createHmac('sha256', params.secret).update(data).digest('hex');
  if (params.signatureV2 && sameHex(hmac(JSON.stringify(sortKeys(params.body))), params.signatureV2)) return true;
  if (params.signature && params.rawBody && sameHex(hmac(params.rawBody), params.signature)) return true;
  return false;
}

interface DiditWarning {
  readonly short_description?: string;
  readonly risk?: string;
  readonly log_type?: string;
}

interface DiditFeatureResult {
  readonly status?: string;
  readonly warnings?: DiditWarning[];
}

interface DiditIdVerification extends DiditFeatureResult {
  readonly document_type?: string | null;
  readonly document_number?: string | null;
  readonly full_name?: string | null;
  readonly first_name?: string | null;
  readonly last_name?: string | null;
  readonly date_of_birth?: string | null;
}

/** The parts of a V3 decision (`GET /v3/session/{id}/decision/` or a webhook's `decision`) that we read. */
export interface DiditDecision {
  readonly session_id?: string;
  readonly status?: string;
  readonly id_verifications?: DiditIdVerification[];
  readonly liveness_checks?: DiditFeatureResult[];
  readonly face_matches?: DiditFeatureResult[];
}

/** What we keep from a decision. Only the last 4 characters of the document number (never a full Aadhaar). */
export interface DecisionSummary {
  readonly documentType: string | null;
  readonly documentLast4: string | null;
  readonly fullName: string | null;
  readonly dateOfBirth: string | null;
  /** Short reasons worth showing a reviewer (or the user, on decline). */
  readonly warnings: string[];
}

export function summarizeDecision(decision: DiditDecision | null | undefined): DecisionSummary {
  const id = decision?.id_verifications?.at(-1);
  const docNumber = (id?.document_number ?? '').replace(/\s+/g, '');
  const name = id?.full_name ?? ([id?.first_name, id?.last_name].filter(Boolean).join(' ') || null);
  const features = [...(decision?.id_verifications ?? []), ...(decision?.liveness_checks ?? []), ...(decision?.face_matches ?? [])];
  const warnings = [
    ...new Set(
      features
        .flatMap((f) => f.warnings ?? [])
        .filter((w) => w.log_type !== 'information')
        .map((w) => w.short_description ?? w.risk ?? '')
        .filter(Boolean),
    ),
  ];
  return {
    documentType: id?.document_type ?? null,
    documentLast4: docNumber ? docNumber.slice(-4) : null,
    fullName: name,
    dateOfBirth: id?.date_of_birth ?? null,
    warnings,
  };
}
