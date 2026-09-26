import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus, Logger } from '@nestjs/common';

import { Prisma } from '../../generated/prisma/client.js';

interface ErrorBody {
  readonly statusCode: number;
  readonly error: string;
  readonly message: string | string[];
  /** Machine-readable reason the apps branch on (e.g. TOO_FAR), when the thrower set one. */
  readonly code?: string;
  readonly details?: Record<string, unknown>;
}

/** Returns one JSON error shape for every failure; maps common Prisma errors to 404 / 409. */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('Errors');

  catch(exception: unknown, host: ArgumentsHost): void {
    const res = host.switchToHttp().getResponse<{ status: (c: number) => { json: (b: ErrorBody) => void } }>();
    const body = this.toBody(exception);
    if (body.statusCode >= 500) this.logger.error(exception);
    res.status(body.statusCode).json(body);
  }

  private toBody(e: unknown): ErrorBody {
    if (e instanceof HttpException) {
      const r = e.getResponse();
      const body = typeof r === 'string' ? {} : (r as { message?: string | string[]; code?: string; details?: Record<string, unknown> });
      const message = typeof r === 'string' ? r : (body.message ?? e.message);
      return { statusCode: e.getStatus(), error: e.name, message, ...(body.code ? { code: body.code } : {}), ...(body.details ? { details: body.details } : {}) };
    }
    if (e instanceof Prisma.PrismaClientKnownRequestError) {
      if (e.code === 'P2025') return { statusCode: HttpStatus.NOT_FOUND, error: 'NotFound', message: 'Not found' };
      if (e.code === 'P2002') return { statusCode: HttpStatus.CONFLICT, error: 'Conflict', message: 'Already exists' };
    }
    return { statusCode: HttpStatus.INTERNAL_SERVER_ERROR, error: 'InternalServerError', message: 'Something went wrong' };
  }
}
