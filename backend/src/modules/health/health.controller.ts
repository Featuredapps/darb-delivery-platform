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
      this.prisma.$queryRaw`SELECT 1`,
      this.redis.ping(),
    ]);

    const [database, redis] = checks.map((check) =>
      check.status === 'fulfilled' ? 'ok' : 'error',
    );
    const ready = database === 'ok' && redis === 'ok';
    const result = {
      status: ready ? 'ok' : 'error',
      checks: { database, redis },
    };

    if (!ready) {
      throw new ServiceUnavailableException(result);
    }

    return result;
  }
}
