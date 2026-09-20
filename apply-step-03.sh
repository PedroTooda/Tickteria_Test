#!/usr/bin/env bash
# =============================================================================
# PASSO 3 — Reserva atômica de capacidade + criação de pedido (POST /orders)
# Rode na RAIZ do projeto:  bash apply-step-03.sh
# Sobrescreve os arquivos abaixo (é um patch, não um scaffold).
# =============================================================================
set -euo pipefail
[ -f package.json ] && [ -d packages/core ] || { echo "Rode na raiz do projeto." >&2; exit 1; }

put() { mkdir -p "$(dirname "$1")"; cat >"$1"; echo "put   $1"; }

C=packages/core/src
I=packages/infra/src
A=apps/api/src

# =============================================================================
# CORE — contratos, erros e caso de uso (zero dependência de framework)
# =============================================================================
put $C/shared/contracts/id-generator.contract.ts <<'EOF'
export interface IdGenerator {
  next(): string;
}
EOF

put $C/ordering/domain/contracts/sector-catalog.contract.ts <<'EOF'
export interface SectorSnapshot {
  id: string;
  priceCents: number;
}

/** Porta de leitura: o ordering consulta setores sem conhecer o ticketing. */
export interface SectorCatalog {
  findByIds(ids: string[]): Promise<SectorSnapshot[]>;
}
EOF

put $C/ordering/domain/contracts/inventory-reservation.contract.ts <<'EOF'
/** Porta do ordering; o adapter no infra delega ao SectorInventoryRepository do ticketing. */
export interface InventoryReservation {
  /** true = reservou; false = esgotado. Deve ser atômico. */
  reserve(sectorId: string, quantity: number): Promise<boolean>;
}
EOF

put $C/ordering/domain/contracts/order-reference-generator.contract.ts <<'EOF'
export interface OrderReferenceGenerator {
  next(): string;
}
EOF

put $C/ordering/domain/errors/invalid-order.error.ts <<'EOF'
import { DomainError } from '../../../shared/errors/domain.error';

export class InvalidOrderError extends DomainError {
  readonly code = 'INVALID_ORDER';
}
EOF

put $C/ordering/domain/errors/sector-not-found.error.ts <<'EOF'
import { DomainError } from '../../../shared/errors/domain.error';

export class SectorNotFoundError extends DomainError {
  readonly code = 'SECTOR_NOT_FOUND';
  constructor(sectorId: string) {
    super(`Setor não encontrado: ${sectorId}`);
  }
}
EOF

put $C/ordering/domain/errors/sector-sold-out.error.ts <<'EOF'
import { DomainError } from '../../../shared/errors/domain.error';

export class SectorSoldOutError extends DomainError {
  readonly code = 'SECTOR_SOLD_OUT';
  constructor(sectorId: string) {
    super(`Ingressos esgotados no setor: ${sectorId}`);
  }
}
EOF

put $C/ordering/application/use-cases/create-order.use-case.ts <<'EOF'
import { Clock } from '../../../shared/contracts/clock.contract';
import { IdGenerator } from '../../../shared/contracts/id-generator.contract';
import { UnitOfWork } from '../../../shared/contracts/unit-of-work.contract';
import { UseCase } from '../../../shared/contracts/use-case.contract';
import { InventoryReservation } from '../../domain/contracts/inventory-reservation.contract';
import { OrderReferenceGenerator } from '../../domain/contracts/order-reference-generator.contract';
import { OrderRepository } from '../../domain/contracts/order.repository.contract';
import { SectorCatalog } from '../../domain/contracts/sector-catalog.contract';
import { Order, OrderItem } from '../../domain/entities/order.entity';
import { InvalidOrderError } from '../../domain/errors/invalid-order.error';
import { SectorNotFoundError } from '../../domain/errors/sector-not-found.error';
import { SectorSoldOutError } from '../../domain/errors/sector-sold-out.error';
import { OrderStatus } from '../../domain/types/order-status.type';
import { CreateOrderDto } from '../dtos/create-order.dto';

export type CreateOrderInput = CreateOrderDto;

export interface CreateOrderOutput {
  orderId: string;
  reference: string;
  status: OrderStatus;
  totalCents: number;
  expiresAt: Date;
}

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MAX_LINES = 10;
const MAX_QUANTITY_PER_LINE = 10; // premissa: limite por compra (ajuste conforme o produto)

export class CreateOrderUseCase implements UseCase<CreateOrderInput, CreateOrderOutput> {
  constructor(
    private readonly uow: UnitOfWork,
    private readonly sectors: SectorCatalog,
    private readonly reservation: InventoryReservation,
    private readonly orders: OrderRepository,
    private readonly references: OrderReferenceGenerator,
    private readonly ids: IdGenerator,
    private readonly clock: Clock,
    private readonly orderTtlMs: number,
  ) {}

  async execute(input: CreateOrderInput): Promise<CreateOrderOutput> {
    const buyerEmail = this.normalizeEmail(input?.buyerEmail);
    const lines = this.normalizeLines(input?.items);

    // Tudo ou nada: se qualquer reserva falhar, o rollback desfaz as anteriores.
    return this.uow.run(async () => {
      const found = await this.sectors.findByIds(lines.map((l) => l.sectorId));
      const priceBySector = new Map(found.map((s) => [s.id, s.priceCents]));

      const items: OrderItem[] = [];
      for (const line of lines) {
        const unitPriceCents = priceBySector.get(line.sectorId);
        if (unitPriceCents === undefined) throw new SectorNotFoundError(line.sectorId);
        const reserved = await this.reservation.reserve(line.sectorId, line.quantity);
        if (!reserved) throw new SectorSoldOutError(line.sectorId);
        items.push({ sectorId: line.sectorId, quantity: line.quantity, unitPriceCents });
      }

      const order: Order = {
        id: this.ids.next(),
        reference: this.references.next(),
        buyerEmail,
        status: OrderStatus.PENDING_PAYMENT,
        totalCents: items.reduce((sum, i) => sum + i.unitPriceCents * i.quantity, 0),
        items,
        expiresAt: new Date(this.clock.now().getTime() + this.orderTtlMs),
      };
      await this.orders.create(order);

      return {
        orderId: order.id,
        reference: order.reference,
        status: order.status,
        totalCents: order.totalCents,
        expiresAt: order.expiresAt,
      };
    });
  }

  private normalizeEmail(email: unknown): string {
    const value = typeof email === 'string' ? email.trim().toLowerCase() : '';
    if (!EMAIL.test(value)) throw new InvalidOrderError('E-mail do comprador inválido');
    return value;
  }

  /** Valida, agrupa setores repetidos e ORDENA por id: ordem fixa de lock evita deadlock. */
  private normalizeLines(items: unknown): { sectorId: string; quantity: number }[] {
    if (!Array.isArray(items) || items.length === 0 || items.length > MAX_LINES) {
      throw new InvalidOrderError(`O pedido deve ter de 1 a ${MAX_LINES} itens`);
    }
    const bySector = new Map<string, number>();
    for (const raw of items as { sectorId?: unknown; quantity?: unknown }[]) {
      const { sectorId, quantity } = raw ?? {};
      if (typeof sectorId !== 'string' || sectorId.length === 0) {
        throw new InvalidOrderError('Item sem sectorId');
      }
      if (!Number.isInteger(quantity) || (quantity as number) < 1) {
        throw new InvalidOrderError('Quantidade deve ser um inteiro maior que zero');
      }
      bySector.set(sectorId, (bySector.get(sectorId) ?? 0) + (quantity as number));
    }
    return [...bySector.entries()]
      .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
      .map(([sectorId, quantity]) => {
        if (quantity > MAX_QUANTITY_PER_LINE) {
          throw new InvalidOrderError(`Máximo de ${MAX_QUANTITY_PER_LINE} ingressos por setor`);
        }
        return { sectorId, quantity };
      });
  }
}
EOF

# =============================================================================
# INFRA — Prisma: transação por AsyncLocalStorage + repositórios
# =============================================================================
put $I/persistence/prisma-transaction-context.ts <<'EOF'
import { AsyncLocalStorage } from 'node:async_hooks';
import { Prisma, PrismaClient } from '@prisma/client';

/**
 * Entrega aos repositórios o cliente da transação corrente (se houver) ou o cliente base.
 * Assim os repositórios não sabem se estão dentro de uma transação.
 */
export class PrismaTransactionContext {
  private readonly storage = new AsyncLocalStorage<Prisma.TransactionClient>();

  constructor(private readonly prisma: PrismaClient) {}

  get client(): Prisma.TransactionClient {
    return this.storage.getStore() ?? this.prisma;
  }

  run<T>(work: () => Promise<T>): Promise<T> {
    if (this.storage.getStore()) return work(); // já está numa transação: reaproveita
    return this.prisma.$transaction((tx) => this.storage.run(tx, work), {
      maxWait: 5000,
      timeout: 10000,
    });
  }
}
EOF

put $I/persistence/prisma-unit-of-work.ts <<'EOF'
import { UnitOfWork } from '@tickteira/core';
import { PrismaTransactionContext } from './prisma-transaction-context';

export class PrismaUnitOfWork implements UnitOfWork {
  constructor(private readonly context: PrismaTransactionContext) {}

  run<T>(work: () => Promise<T>): Promise<T> {
    return this.context.run(work);
  }
}
EOF

put $I/persistence/repositories/prisma-sector-inventory.repository.ts <<'EOF'
import { SectorInventoryRepository } from '@tickteira/core';
import { PrismaTransactionContext } from '../prisma-transaction-context';

export class PrismaSectorInventoryRepository implements SectorInventoryRepository {
  constructor(private readonly context: PrismaTransactionContext) {}

  /** UPDATE condicional atômico: o Postgres serializa por linha; nunca passa da capacidade. */
  async tryAllocate(sectorId: string, quantity: number): Promise<boolean> {
    const affected = await this.context.client.$executeRaw`
      UPDATE sectors
         SET allocated = allocated + ${quantity}::int
       WHERE id = ${sectorId}
         AND allocated + ${quantity}::int <= capacity`;
    return affected === 1;
  }
}
EOF

put $I/persistence/repositories/prisma-sector-catalog.repository.ts <<'EOF'
import { SectorCatalog, SectorSnapshot } from '@tickteira/core';
import { PrismaTransactionContext } from '../prisma-transaction-context';

export class PrismaSectorCatalog implements SectorCatalog {
  constructor(private readonly context: PrismaTransactionContext) {}

  async findByIds(ids: string[]): Promise<SectorSnapshot[]> {
    const rows = await this.context.client.sector.findMany({
      where: { id: { in: ids } },
      select: { id: true, priceCents: true },
    });
    return rows;
  }
}
EOF

put $I/persistence/repositories/prisma-order.repository.ts <<'EOF'
import { Order, OrderRepository, OrderStatus } from '@tickteira/core';
import { PrismaTransactionContext } from '../prisma-transaction-context';

export class PrismaOrderRepository implements OrderRepository {
  constructor(private readonly context: PrismaTransactionContext) {}

  async create(order: Order): Promise<void> {
    await this.context.client.order.create({
      data: {
        id: order.id,
        reference: order.reference,
        buyerEmail: order.buyerEmail,
        status: order.status,
        totalCents: order.totalCents,
        expiresAt: order.expiresAt,
        items: {
          create: order.items.map((i) => ({
            sectorId: i.sectorId,
            quantity: i.quantity,
            unitPriceCents: i.unitPriceCents,
          })),
        },
      },
    });
  }

  /** Lock pessimista: só faz sentido dentro de um UnitOfWork. */
  async findByReferenceForUpdate(reference: string): Promise<Order | null> {
    const client = this.context.client;
    const locked = await client.$queryRaw<{ id: string }[]>`
      SELECT id FROM orders WHERE reference = ${reference} FOR UPDATE`;
    const id = locked[0]?.id;
    if (!id) return null;

    const record = await client.order.findUnique({ where: { id }, include: { items: true } });
    if (!record) return null;
    return {
      id: record.id,
      reference: record.reference,
      buyerEmail: record.buyerEmail,
      status: record.status as OrderStatus,
      totalCents: record.totalCents,
      expiresAt: record.expiresAt,
      items: record.items.map((i) => ({
        sectorId: i.sectorId,
        quantity: i.quantity,
        unitPriceCents: i.unitPriceCents,
      })),
    };
  }

  async save(order: Order): Promise<void> {
    await this.context.client.order.update({
      where: { id: order.id },
      data: { status: order.status, totalCents: order.totalCents },
    });
  }
}
EOF

put $I/adapters/inventory-reservation.adapter.ts <<'EOF'
import { InventoryReservation, SectorInventoryRepository } from '@tickteira/core';

/** Ponte entre contextos: o ordering pede "reservar", o ticketing sabe "alocar". */
export class InventoryReservationAdapter implements InventoryReservation {
  constructor(private readonly inventory: SectorInventoryRepository) {}

  reserve(sectorId: string, quantity: number): Promise<boolean> {
    return this.inventory.tryAllocate(sectorId, quantity);
  }
}
EOF

put $I/generators/uuid.generator.ts <<'EOF'
import { randomUUID } from 'node:crypto';
import { IdGenerator } from '@tickteira/core';

export class UuidGenerator implements IdGenerator {
  next(): string {
    return randomUUID();
  }
}
EOF

put $I/generators/random-order-reference.generator.ts <<'EOF'
import { randomBytes } from 'node:crypto';
import { OrderReferenceGenerator } from '@tickteira/core';

const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; // Crockford base32 (sem I, L, O, U)

/** TKT-XXXXXXXX: 32^8 combinações; colisão é barrada pelo UNIQUE de orders.reference. */
export class RandomOrderReferenceGenerator implements OrderReferenceGenerator {
  next(): string {
    const bytes = randomBytes(8);
    let code = '';
    for (const byte of bytes) code += ALPHABET[byte % 32];
    return `TKT-${code}`;
  }
}
EOF

put $I/index.ts <<'EOF'
export { Prisma, PrismaClient } from '@prisma/client';
export { Redis } from 'ioredis';
export * from './persistence/prisma.factory';
export * from './persistence/prisma-transaction-context';
export * from './persistence/prisma-unit-of-work';
export * from './persistence/repositories/prisma-sector-inventory.repository';
export * from './persistence/repositories/prisma-sector-catalog.repository';
export * from './persistence/repositories/prisma-order.repository';
export * from './adapters/inventory-reservation.adapter';
export * from './generators/uuid.generator';
export * from './generators/random-order-reference.generator';
export * from './queue/redis.factory';
export * from './security/hmac-signature.verifier';
export * from './clock/system.clock';
EOF

# =============================================================================
# API — tokens, composition root, filtro de erros e POST /orders
# =============================================================================
put $A/shared/di-tokens.ts <<'EOF'
// Tokens de injeção: ligam contratos (interfaces) às implementações do infra.
export const TOKENS = {
  Prisma: Symbol('Prisma'),
  Redis: Symbol('Redis'),
  TransactionContext: Symbol('TransactionContext'),
  UnitOfWork: Symbol('UnitOfWork'),
  Clock: Symbol('Clock'),
  IdGenerator: Symbol('IdGenerator'),
  SectorInventory: Symbol('SectorInventory'),
  InventoryReservation: Symbol('InventoryReservation'),
  SectorCatalog: Symbol('SectorCatalog'),
  OrderRepository: Symbol('OrderRepository'),
  OrderReferenceGenerator: Symbol('OrderReferenceGenerator'),
  CreateOrder: Symbol('CreateOrder'),
} as const;
EOF

put $A/shared/infra.module.ts <<'EOF'
import { Global, Module, Provider } from '@nestjs/common';
import {
  InventoryReservationAdapter,
  PrismaClient,
  PrismaOrderRepository,
  PrismaSectorCatalog,
  PrismaSectorInventoryRepository,
  PrismaTransactionContext,
  PrismaUnitOfWork,
  RandomOrderReferenceGenerator,
  SystemClock,
  UuidGenerator,
  createPrismaClient,
  createRedis,
} from '@tickteira/infra';
import { SectorInventoryRepository } from '@tickteira/core';
import { TOKENS } from './di-tokens';

// Composition root: único lugar do api que instancia implementações concretas.
const providers: (Provider & { provide: symbol })[] = [
  { provide: TOKENS.Prisma, useFactory: () => createPrismaClient() },
  {
    provide: TOKENS.Redis,
    useFactory: () => createRedis(process.env.REDIS_URL ?? 'redis://localhost:6379'),
  },
  {
    provide: TOKENS.TransactionContext,
    useFactory: (prisma: PrismaClient) => new PrismaTransactionContext(prisma),
    inject: [TOKENS.Prisma],
  },
  {
    provide: TOKENS.UnitOfWork,
    useFactory: (ctx: PrismaTransactionContext) => new PrismaUnitOfWork(ctx),
    inject: [TOKENS.TransactionContext],
  },
  { provide: TOKENS.Clock, useValue: new SystemClock() },
  { provide: TOKENS.IdGenerator, useValue: new UuidGenerator() },
  {
    provide: TOKENS.SectorInventory,
    useFactory: (ctx: PrismaTransactionContext) => new PrismaSectorInventoryRepository(ctx),
    inject: [TOKENS.TransactionContext],
  },
  {
    provide: TOKENS.InventoryReservation,
    useFactory: (inventory: SectorInventoryRepository) =>
      new InventoryReservationAdapter(inventory),
    inject: [TOKENS.SectorInventory],
  },
  {
    provide: TOKENS.SectorCatalog,
    useFactory: (ctx: PrismaTransactionContext) => new PrismaSectorCatalog(ctx),
    inject: [TOKENS.TransactionContext],
  },
  {
    provide: TOKENS.OrderRepository,
    useFactory: (ctx: PrismaTransactionContext) => new PrismaOrderRepository(ctx),
    inject: [TOKENS.TransactionContext],
  },
  { provide: TOKENS.OrderReferenceGenerator, useValue: new RandomOrderReferenceGenerator() },
];

@Global()
@Module({ providers, exports: providers.map((p) => p.provide) })
export class InfraModule {}
EOF

put $A/shared/api-exception.filter.ts <<'EOF'
import { ArgumentsHost, Catch, ExceptionFilter, HttpException, Logger } from '@nestjs/common';
import { DomainError } from '@tickteira/core';

type HttpResponse = { status(code: number): { json(body: unknown): void } };

// Erros de domínio -> status HTTP. Novos erros: acrescente o code aqui.
const STATUS_BY_CODE: Record<string, number> = {
  INVALID_ORDER: 400,
  SECTOR_NOT_FOUND: 404,
  SECTOR_SOLD_OUT: 409,
  INVALID_SIGNATURE: 401,
};

@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(ApiExceptionFilter.name);

  catch(error: unknown, host: ArgumentsHost): void {
    const res = host.switchToHttp().getResponse<HttpResponse>();

    if (error instanceof DomainError) {
      res.status(STATUS_BY_CODE[error.code] ?? 422).json({ code: error.code, message: error.message });
      return;
    }
    if (error instanceof HttpException) {
      res.status(error.getStatus()).json(error.getResponse());
      return;
    }
    this.logger.error(error);
    res.status(500).json({ code: 'INTERNAL_ERROR', message: 'Erro interno' });
  }
}
EOF

put $A/main.ts <<'EOF'
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ApiExceptionFilter } from './shared/api-exception.filter';

async function bootstrap() {
  // rawBody: true é obrigatório — o HMAC é calculado sobre os bytes originais.
  const app = await NestFactory.create(AppModule, { rawBody: true });
  app.enableCors();
  app.enableShutdownHooks();
  app.useGlobalFilters(new ApiExceptionFilter());
  await app.listen(Number(process.env.API_PORT ?? 3001), '0.0.0.0');
}
void bootstrap();
EOF

put $A/modules/orders/orders.controller.ts <<'EOF'
import { Body, Controller, HttpCode, Inject, Post } from '@nestjs/common';
import {
  CreateOrderDto,
  CreateOrderInput,
  CreateOrderOutput,
  UseCase,
} from '@tickteira/core';
import { TOKENS } from '../../shared/di-tokens';

// Controller fino: HTTP -> UseCase.execute(). Sem regra de negócio.
@Controller('orders')
export class OrdersController {
  constructor(
    @Inject(TOKENS.CreateOrder)
    private readonly createOrder: UseCase<CreateOrderInput, CreateOrderOutput>,
  ) {}

  @Post()
  @HttpCode(201)
  create(@Body() body: CreateOrderDto): Promise<CreateOrderOutput> {
    return this.createOrder.execute(body);
  }
}
EOF

put $A/modules/orders/orders.module.ts <<'EOF'
import { Module } from '@nestjs/common';
import {
  Clock,
  CreateOrderUseCase,
  IdGenerator,
  InventoryReservation,
  OrderReferenceGenerator,
  OrderRepository,
  SectorCatalog,
  UnitOfWork,
} from '@tickteira/core';
import { TOKENS } from '../../shared/di-tokens';
import { OrdersController } from './orders.controller';

const ORDER_TTL_MS = Number(process.env.ORDER_TTL_MINUTES ?? 15) * 60_000;

@Module({
  controllers: [OrdersController],
  providers: [
    {
      provide: TOKENS.CreateOrder,
      useFactory: (
        uow: UnitOfWork,
        sectors: SectorCatalog,
        reservation: InventoryReservation,
        orders: OrderRepository,
        references: OrderReferenceGenerator,
        ids: IdGenerator,
        clock: Clock,
      ) =>
        new CreateOrderUseCase(uow, sectors, reservation, orders, references, ids, clock, ORDER_TTL_MS),
      inject: [
        TOKENS.UnitOfWork,
        TOKENS.SectorCatalog,
        TOKENS.InventoryReservation,
        TOKENS.OrderRepository,
        TOKENS.OrderReferenceGenerator,
        TOKENS.IdGenerator,
        TOKENS.Clock,
      ],
    },
  ],
})
export class OrdersModule {}
EOF

# =============================================================================
# Regenera o barrel do core (novos arquivos)
# =============================================================================
{
  echo "// GERADO por scaffold — não editar à mão"
  (cd $C && find . -name '*.ts' ! -name index.ts | sort | sed -E 's|\.ts$||; s|^|export * from "|; s|$|";|')
} >$C/index.ts
echo "gen   $C/index.ts"

cat <<'EOF'

Passo 3 aplicado. Valide:
  npm run build:packages
  npm run build:backend
  npm run check:arch
  docker compose up --build
EOF
