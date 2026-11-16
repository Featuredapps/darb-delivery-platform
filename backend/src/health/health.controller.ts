import { Controller, Get, Inject, ServiceUnavailableException } from '@nestjs/common';
import type Redis from 'ioredis';
import { PrismaService } from '../prisma/prisma.service';
import { REDIS } from '../redis/redis.module';

@Controller('health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: Redis,
  ) {}

  @Get()
  async readiness() {
    const checks = await Promise.allSettled([
      this.prisma.$queryRaw`SELECT 1`,
      this.redis.ping(),
    ]);
    const database = checks[0].status === 'fulfilled';
    const cache = checks[1].status === 'fulfilled' && checks[1].value === 'PONG';
    const result = {
      status: database && cache ? 'ok' : 'unavailable',
      checks: { database: database ? 'ok' : 'error', redis: cache ? 'ok' : 'error' },
      timestamp: new Date().toISOString(),
    };
    if (!database || !cache) throw new ServiceUnavailableException(result);
    return result;
  }
}
