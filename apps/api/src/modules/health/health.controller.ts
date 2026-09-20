import { Controller, Get, Inject } from '@nestjs/common';
import { PrismaClient, Redis } from '@tickteira/infra';
import { TOKENS } from '../../shared/di-tokens';

@Controller('health')
export class HealthController {
  constructor(
    @Inject(TOKENS.Prisma) private readonly prisma: PrismaClient,
    @Inject(TOKENS.Redis) private readonly redis: Redis,
  ) {}

  @Get()
  async check() {
    await this.prisma.$queryRaw`SELECT 1`;
    const pong = await this.redis.ping();
    return { status: 'ok', db: 'up', redis: pong === 'PONG' ? 'up' : 'down' };
  }
}
