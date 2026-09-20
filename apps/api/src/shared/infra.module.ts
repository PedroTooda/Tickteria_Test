import { Global, Module } from '@nestjs/common';
import { createPrismaClient, createRedis } from '@tickteira/infra';
import { TOKENS } from './di-tokens';

// Composition root: único lugar do api que instancia implementações concretas.
@Global()
@Module({
  providers: [
    { provide: TOKENS.Prisma, useFactory: () => createPrismaClient() },
    {
      provide: TOKENS.Redis,
      useFactory: () => createRedis(process.env.REDIS_URL ?? 'redis://localhost:6379'),
    },
  ],
  exports: [TOKENS.Prisma, TOKENS.Redis],
})
export class InfraModule {}
