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
  HmacSignatureVerifier,
  PrismaWebhookEventRepository,
  BullMqPaymentEventQueue,
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
        {
      provide: TOKENS.SignatureVerifier,
      useFactory: () => new HmacSignatureVerifier(process.env.PAGFACIL_WEBHOOK_SECRET ?? 'dev-secret-change-me'),
    },
    {
      provide: TOKENS.WebhookEventRepository,
      useFactory: (ctx) => new PrismaWebhookEventRepository(ctx),
      inject: [TOKENS.PrismaContext],
    },
    {
      provide: TOKENS.PaymentEventQueue,
      useFactory: () => new BullMqPaymentEventQueue(process.env.REDIS_URL ?? 'redis://localhost:6379'),
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
    TOKENS.SignatureVerifier,
    TOKENS.WebhookEventRepository,
    TOKENS.PaymentEventQueue,
  ],
})
export class InfraModule {}