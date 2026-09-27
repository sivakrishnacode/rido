import { Inject, Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';

import type { Env } from '../../core/config/env.js';
import { ENV } from '../../core/config/env.token.js';
import type { DiditDecision } from './didit.js';

const TIMEOUT_MS = 10_000;

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
