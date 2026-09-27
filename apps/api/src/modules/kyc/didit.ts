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
  /** `reference_image`: short-lived link to the live selfie. */
  readonly liveness_checks?: (DiditFeatureResult & { readonly reference_image?: string | null })[];
  readonly face_matches?: DiditFeatureResult[];
}

/** One scanned ID: its type as Didit names it ("Driving License", "Identity Card"…) and the number's last 4. */
export interface ScannedDocument {
  readonly type: string;
  readonly last4: string | null;
}

/** What we keep from a decision. Only the last 4 characters of document numbers (never a full Aadhaar). */
export interface DecisionSummary {
  /** The driving licence when one was scanned, else the last document. */
  readonly documentType: string | null;
  readonly documentLast4: string | null;
  /** Every document scanned in the session (drivers: licence + Aadhaar). */
  readonly documents: ScannedDocument[];
  readonly hasDrivingLicence: boolean;
  readonly fullName: string | null;
  readonly dateOfBirth: string | null;
  /** Every non-informational Didit warning, for the admin panel. */
  readonly warnings: string[];
  /** What the user must fix: only the warnings that fail a step, in plain words, e.g. "Driving licence: …". */
  readonly reasons: string[];
}


const last4 = (n: string | null | undefined): string | null => {
  const clean = (n ?? '').replace(/\s+/g, '');
  return clean ? clean.slice(-4) : null;
};

/** Didit document names for a driving licence ("Driving License", "Driver's License", code "DL"). */
export const isDrivingLicence = (type: string | null | undefined): boolean => /driv|^dl$/i.test(type ?? '');

/** Didit risk codes → what the user should do differently. Anything unlisted falls back to Didit's own text. */
const FIXES: Record<string, string> = {
  SCREEN_CAPTURE_DETECTED: 'this looks like a photo of a screen. Scan the real card, not a photo or a phone / laptop screen',
  PRINTED_COPY_DETECTED: 'this looks like a printout or photocopy. Scan the original card',
  PORTRAIT_REPLACED: 'the photo on the card looks altered. Scan the original card',
  DOCUMENT_LIVENESS_FAILED: 'scan the original card, not a photo, copy or screen',
  DOCUMENT_EXPIRED: 'this document has expired. Use a valid one',
  COULD_NOT_RECOGNIZE_DOCUMENT: "we couldn't recognise the card. Scan the front and back in good light",
  NAME_NOT_DETECTED: 'the name wasn\'t readable. Hold the card flat in good light, with no glare',
  DATE_OF_BIRTH_NOT_DETECTED: "the date of birth wasn't readable. Hold the card flat in good light, with no glare",
  DOCUMENT_NUMBER_NOT_DETECTED: "the number wasn't readable. Hold the card flat in good light, with no glare",
  EXPIRATION_DATE_NOT_DETECTED: "the expiry date wasn't readable. Keep all four corners in the frame",
  MIN_AGE_NOT_REACHED: 'you must be 18 or older',
  DUPLICATED_DOCUMENT: 'this document is already used by another Rido account. Contact support',
  LOW_LIVENESS_SCORE: 'the selfie check failed. Face the camera in good light, without a mask or sunglasses',
  LOW_FACE_MATCH_SIMILARITY: "your selfie doesn't match the photo on the ID. Retake it in good light",
  DUPLICATED_FACE: 'this face is already used by another Rido account. Contact support',
};

function reasonsFor(label: string, feature: DiditFeatureResult): string[] {
  return (feature.warnings ?? [])
    .filter((w) => w.log_type === 'error')
    .map((w) => `${label}: ${FIXES[w.risk ?? ''] ?? (w.short_description ?? w.risk ?? 'failed').replace(/\.$/, '')}`);
}

/** [idLabel] names the non-licence ID in reasons (drivers: "Aadhaar"). */
export function summarizeDecision(decision: DiditDecision | null | undefined, idLabel = 'ID card'): DecisionSummary {
  const ids = decision?.id_verifications ?? [];
  const licence = ids.find((d) => isDrivingLicence(d.document_type));
  const id = licence ?? ids.at(-1);
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
  const reasons = [
    ...new Set([
      ...ids.flatMap((d) => reasonsFor(isDrivingLicence(d.document_type) ? 'Driving licence' : idLabel, d)),
      ...(decision?.liveness_checks ?? []).flatMap((f) => reasonsFor('Selfie', f)),
      ...(decision?.face_matches ?? []).flatMap((f) => reasonsFor('Selfie', f)),
    ]),
  ];
  return {
    documentType: id?.document_type ?? null,
    documentLast4: last4(id?.document_number),
    documents: ids.filter((d) => d.document_type).map((d) => ({ type: d.document_type as string, last4: last4(d.document_number) })),
    hasDrivingLicence: !!licence,
    fullName: name,
    dateOfBirth: id?.date_of_birth ?? null,
    warnings,
    reasons,
  };
}

/** The live selfie of the latest liveness check (a short-lived presigned URL), if the session has one. */
export function selfieUrl(decision: DiditDecision | null | undefined): string | null {
  const url = decision?.liveness_checks?.at(-1)?.reference_image;
  return url?.startsWith('https://') ? url : null;
}
