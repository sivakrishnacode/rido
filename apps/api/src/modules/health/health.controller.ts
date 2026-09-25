import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';

import { Public } from '../../core/auth/public.decorator.js';
import { PrismaService } from '../../core/prisma/prisma.service.js';
import { RedisService } from '../../core/redis/redis.service.js';

/** Liveness and readiness for Docker / load balancers. */
@Public()
@Controller('health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  @Get()
  live(): { status: 'ok' } {
    return { status: 'ok' };
  }

  @Get('ready')
  async ready(): Promise<{ status: 'ok'; database: 'up'; redis: 'up' }> {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      await this.redis.ping();
      return { status: 'ok', database: 'up', redis: 'up' };
    } catch {
      throw new ServiceUnavailableException('Database or Redis is not reachable');
    }
  }
}
