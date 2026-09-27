import { Inject, Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';

import type { Env } from '../../core/config/env.js';
import { ENV } from '../../core/config/env.token.js';
import type { DiditDecision } from './didit.js';

const TIMEOUT_MS = 10_000;
/** Face-match score (0–100) above which a new profile photo counts as the verified person. */
export const FACE_MATCH_MIN_SCORE = 80;

/** A new (or reused, unfinished) hosted session. The app passes [sessionToken] to the in-app SDK. */
export interface DiditSession {
  readonly sessionId: string;
  readonly sessionToken: string;
  readonly status: string;
}

/** Thin client for Didit's Verification API (server-side only: the API key never reaches the apps). */
@Injectable()
export class DiditClient {
  private readonly logger = new Logger(DiditClient.name);

  constructor(@Inject(ENV) private readonly env: Env) {}

  get isEnabled(): boolean {
    return this.env.didit.apiKey.length > 0;
  }

  /** POST /v3/session/. Didit returns the same unfinished session for the same (workflow, vendor_data). */
  async createSession(params: {
    workflowId: string;
    userId: string;
    metadata: Record<string, string>;
    expected: { firstName?: string; lastName?: string; documentTypes: string[] };
  }): Promise<DiditSession> {
    const body = {
      workflow_id: params.workflowId,
      vendor_data: params.userId,
      metadata: params.metadata,
      language: 'en',
      expected_details: {
        ...(params.expected.firstName ? { first_name: params.expected.firstName } : {}),
        ...(params.expected.lastName ? { last_name: params.expected.lastName } : {}),
        id_country: 'IND',
        expected_document_types: params.expected.documentTypes,
      },
    };
    const res = await this.call('/v3/session/', { method: 'POST', body: JSON.stringify(body) });
    const json = (await res.json()) as { session_id: string; session_token: string; status: string };
    return { sessionId: json.session_id, sessionToken: json.session_token, status: json.status };
  }

  /** GET /v3/session/{id}/decision/: the full V3 decision (status + per-feature arrays). */
  async decision(sessionId: string): Promise<DiditDecision> {
    const res = await this.call(`/v3/session/${encodeURIComponent(sessionId)}/decision/`, { method: 'GET' });
    return (await res.json()) as DiditDecision;
  }

  /**
   * POST /v3/face-match/: is [photo] the same person as [reference]? `faces` = faces found in the photo.
   * Throws ServiceUnavailableException when Didit can't be reached.
   */
  async faceMatch(params: {
    photo: { buffer: Buffer; type: string };
    reference: { buffer: Buffer; type: string };
    vendorData: string;
  }): Promise<{ score: number | null; faces: number; isMatch: boolean }> {
    const form = new FormData();
    form.append('user_image', new Blob([new Uint8Array(params.photo.buffer)], { type: params.photo.type }), 'photo');
    form.append('ref_image', new Blob([new Uint8Array(params.reference.buffer)], { type: params.reference.type }), 'selfie');
    form.append('face_match_score_decline_threshold', String(FACE_MATCH_MIN_SCORE));
    form.append('vendor_data', params.vendorData);
    let res: Response;
    try {
      res = await fetch(`${this.env.didit.baseUrl}/v3/face-match/`, {
        method: 'POST',
        headers: { 'x-api-key': this.env.didit.apiKey, accept: 'application/json' },
        body: form,
        signal: AbortSignal.timeout(20_000),
      });
    } catch (e) {
      this.logger.warn(`Didit face match failed: ${(e as Error).message}`);
      throw new ServiceUnavailableException('Photo check is unavailable right now');
    }
    if (!res.ok) {
      this.logger.warn(`Didit face match → ${res.status}: ${(await res.text()).slice(0, 300)}`);
      throw new ServiceUnavailableException('Photo check is unavailable right now');
    }
    const json = (await res.json()) as { face_match?: { status?: string; score?: number | null; user_image?: { entities?: unknown[] } } };
    const fm = json.face_match ?? {};
    return { score: fm.score ?? null, faces: fm.user_image?.entities?.length ?? 0, isMatch: fm.status === 'Approved' };
  }

  /** Downloads a Didit media link (selfie). JPG / PNG / WebP up to 8 MB, else null. */
  async image(url: string): Promise<{ buffer: Buffer; mimetype: string } | null> {
    try {
      const res = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
      const mimetype = (res.headers.get('content-type') ?? '').split(';')[0].trim();
      if (!res.ok || !['image/jpeg', 'image/png', 'image/webp'].includes(mimetype)) return null;
      const buffer = Buffer.from(await res.arrayBuffer());
      return buffer.length > 0 && buffer.length <= 8 * 1024 * 1024 ? { buffer, mimetype } : null;
    } catch (e) {
      this.logger.warn(`Didit image download failed: ${(e as Error).message}`);
      return null;
    }
  }

  private async call(path: string, init: RequestInit): Promise<Response> {
    let res: Response;
    try {
      res = await fetch(`${this.env.didit.baseUrl}${path}`, {
        ...init,
        headers: { 'x-api-key': this.env.didit.apiKey, 'content-type': 'application/json', accept: 'application/json' },
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
    } catch (e) {
      this.logger.warn(`Didit ${path} failed: ${(e as Error).message}`);
      throw new ServiceUnavailableException('Verification is unavailable right now. Please try again');
    }
    if (res.ok) return res;
    const text = await res.text();
    this.logger.warn(`Didit ${path} → ${res.status}: ${text.slice(0, 300)}`);
    // Out of free sessions / credits, or rate limited: the user can simply try later.
    if (/credits/i.test(text) || res.status === 429) {
      throw new ServiceUnavailableException('Verification is busy right now. Please try again later');
    }
    throw new ServiceUnavailableException('Verification is unavailable right now. Please try again');
  }
}
