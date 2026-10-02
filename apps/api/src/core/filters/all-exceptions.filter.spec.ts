import type { ArgumentsHost } from '@nestjs/common';
import { HttpException, Logger, NotFoundException } from '@nestjs/common';

import { Prisma } from '../../generated/prisma/client.js';
import { RATE_LIMIT_MESSAGE, TooManyRequestsException } from '../rate-limit/rate-limit.js';
import { AllExceptionsFilter } from './all-exceptions.filter.js';

/** Runs the filter on [e]; returns the status, JSON body and headers it sent. */
function respond(e: unknown): { status: number; body: Record<string, unknown>; headers: Record<string, string> } {
  const out = { status: 0, body: {} as Record<string, unknown>, headers: {} as Record<string, string> };
  const res = {
    setHeader: (k: string, v: string) => void (out.headers[k] = v),
    status: (c: number) => {
      out.status = c;
      return { json: (b: Record<string, unknown>) => void (out.body = b) };
    },
  };
  const host = { switchToHttp: () => ({ getResponse: () => res }) } as unknown as ArgumentsHost;
  new AllExceptionsFilter().catch(e, host);
  return out;
}

const prismaError = (code: string): Prisma.PrismaClientKnownRequestError =>
  new Prisma.PrismaClientKnownRequestError('db', { code, clientVersion: 'test' });

describe('AllExceptionsFilter', () => {
  it('maps Prisma not found / unique / foreign key errors to 404 / 409 / 400', () => {
    expect(respond(prismaError('P2025')).status).toBe(404);
    expect(respond(prismaError('P2002')).status).toBe(409);
    expect(respond(prismaError('P2003'))).toMatchObject({ status: 400, body: { statusCode: 400, error: 'BadRequest' } });
  });

  it('keeps HTTP errors as thrown and hides anything else behind a 500', () => {
    vi.spyOn(Logger.prototype, 'error').mockImplementation(() => undefined); // the 500 is logged
    expect(respond(new NotFoundException('Trip not found')).body).toMatchObject({ statusCode: 404, message: 'Trip not found' });
    expect(respond(new Error('boom')).body).toEqual({ statusCode: 500, error: 'InternalServerError', message: 'Something went wrong' });
  });

  it('sends Retry-After with a 429 that carries details.retryInSeconds', () => {
    const out = respond(new TooManyRequestsException(42.2));
    expect(out).toMatchObject({ status: 429, body: { statusCode: 429, message: RATE_LIMIT_MESSAGE, code: 'RATE_LIMITED', details: { retryInSeconds: 43 } } });
    expect(out.headers['Retry-After']).toBe('43');
    expect(respond(new HttpException('Too many', 429)).headers['Retry-After']).toBeUndefined();
  });
});
