import { Global, Module } from '@nestjs/common';
import {
  PrismaContext,
  PrismaOrderRepository,
  PrismaSectorCatalogRepository,
  PrismaSectorInventoryRepository,
  PrismaUnitOfWork,
  SystemClock,
  UuidIdGenerator,
  createPrismaClient,
  createRedis,
} from '@tickteira/infra';
import { TOKENS } from './di-tokens';

@Global()
@Module({
  providers: [
    { provide: TOKENS.Prisma, useFactory: () => createPrismaClient() },
    {
      provide: TOKENS.Redis,
      useFactory: () => createRedis(process.env.REDIS_URL ?? 'redis://localhost:6379'),
    },
    { provide: TOKENS.PrismaContext, useFactory: (p) => new PrismaContext(p), inject: [TOKENS.Prisma] },
    { provide: TOKENS.Clock, useClass: SystemClock },
    { provide: TOKENS.IdGenerator, useClass: UuidIdGenerator },
    {
      provide: TOKENS.UnitOfWork,
      useFactory: (ctx, p) => new PrismaUnitOfWork(ctx, p),
      inject: [TOKENS.PrismaContext, TOKENS.Prisma],
    },
    {
      provide: TOKENS.OrderRepository,
      useFactory: (ctx) => new PrismaOrderRepository(ctx),
      inject: [TOKENS.PrismaContext],
    },
    {
      provide: TOKENS.SectorCatalogRepository,
      useFactory: (ctx) => new PrismaSectorCatalogRepository(ctx),
      inject: [TOKENS.PrismaContext],
    },
    {
      provide: TOKENS.SectorInventoryRepository,
      useFactory: (ctx) => new PrismaSectorInventoryRepository(ctx),
      inject: [TOKENS.PrismaContext],
    },
  ],
  exports: [
    TOKENS.Prisma,
    TOKENS.Redis,
    TOKENS.PrismaContext,
    TOKENS.Clock,
    TOKENS.IdGenerator,
    TOKENS.UnitOfWork,
    TOKENS.OrderRepository,
    TOKENS.SectorCatalogRepository,
    TOKENS.SectorInventoryRepository,
  ],
})
export class InfraModule {}