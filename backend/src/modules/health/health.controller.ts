import {
  Controller,
  Get,
  Inject,
  ServiceUnavailableException,
} from '@nestjs/common';
import Redis from 'ioredis';
import { PrismaService } from '../../prisma/prisma.service';
import { REDIS } from '../../redis/redis.module';

@Controller()
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: Redis,
  ) {}

  @Get('healthz')
  liveness() {
    return { status: 'ok' };
  }

  @Get('readyz')
  async readiness() {
    const checks = await Promise.allSettled([
      this.prisma.$queryRaw<Array<{ users_table: string | null }>>`SELECT to_regclass('public."User"')::text AS users_table`,
      this.redis.ping(),
    ]);

    const databaseReady =
      checks[0].status === 'fulfilled' &&
      Boolean(checks[0].value[0]?.users_table);
    const redisReady =
      checks[1].status === 'fulfilled' && checks[1].value === 'PONG';
    const ready = databaseReady && redisReady;
    const result = {
      status: ready ? 'ok' : 'error',
      checks: {
        database: databaseReady ? 'ok' : 'not_ready',
        redis: redisReady ? 'ok' : 'not_ready',
      },
    };

    if (!ready) {
      throw new ServiceUnavailableException(result);
    }

    return result;
  }
}
