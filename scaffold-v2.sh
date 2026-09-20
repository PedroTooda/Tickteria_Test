#!/usr/bin/env bash
# =============================================================================
# Tickteira — scaffold v2 (DDD + SOLID + contratos), pronto para subir no Docker
#
# Uso (dentro de uma pasta VAZIA, só o .git pode existir):
#     bash scaffold-v2.sh .
#     npm install            # gera o package-lock.json (obrigatório p/ o Docker)
#     docker compose up --build
#
# O que já funciona ao final: postgres + redis + mailpit + migrate (schema e seed)
# + api (GET /health) + 3 workers (BullMQ) + web (Next). Sem regra de negócio ainda.
# =============================================================================
set -euo pipefail

ROOT="${1:-tickteira}"
mkdir -p "$ROOT"

# Guarda: evita misturar com arquivos antigos (write nunca sobrescreve).
if [ -n "$(ls -A "$ROOT" | grep -Ev '^(\.git|scaffold.*\.sh)$' || true)" ]; then
  echo "ERRO: a pasta '$ROOT' não está vazia. Use uma pasta nova ou apague o conteúdo (mantenha o .git)." >&2
  exit 1
fi
cd "$ROOT"

# write <caminho>  -> grava o stdin no arquivo, sem sobrescrever
write() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  if [[ -e "$path" ]]; then echo "skip  $path"; cat >/dev/null; return; fi
  cat >"$path"
  echo "ok    $path"
}

# usecase <caminho> <NomeDaClasse>  -> esqueleto de caso de uso (contrato UseCase)
usecase() {
  write "$1" <<EOF
import { UseCase } from '../../../shared/contracts/use-case.contract';

// TODO: definir o contrato de entrada e saída desta operação
export type ${2}Input = Record<string, never>;
export type ${2}Output = void;

export class ${2}UseCase implements UseCase<${2}Input, ${2}Output> {
  // Dependências entram pelo construtor e são SEMPRE contratos (interfaces).
  async execute(_input: ${2}Input): Promise<${2}Output> {
    throw new Error('${2}UseCase não implementado');
  }
}
EOF
}

# =============================================================================
# 1. RAIZ
# =============================================================================
write package.json <<'EOF'
{
  "name": "tickteira",
  "private": true,
  "workspaces": ["apps/*", "packages/*"],
  "scripts": {
    "build:packages": "npm run build -w @tickteira/core && npm run build -w @tickteira/infra",
    "build:backend": "npm run build -w @tickteira/api && npm run build -w @tickteira/worker",
    "check:arch": "bash scripts/check-architecture.sh",
    "db:generate": "prisma generate --schema packages/infra/prisma/schema.prisma",
    "db:migrate": "prisma migrate deploy --schema packages/infra/prisma/schema.prisma",
    "db:seed": "node packages/infra/prisma/seed.js",
    "simulate": "ts-node scripts/webhook-simulator/index.ts"
  },
  "devDependencies": {
    "@types/node": "^22.0.0",
    "prisma": "^6.0.0",
    "ts-node": "^10.9.2",
    "typescript": "^5.6.0"
  }
}
EOF

write tsconfig.base.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "node16",
    "moduleResolution": "node16",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "declaration": true,
    "sourceMap": true
  }
}
EOF

# usado só pelos scripts (ts-node) rodando da raiz
write tsconfig.json <<'EOF'
{
  "extends": "./tsconfig.base.json",
  "include": ["scripts"]
}
EOF

write .gitignore <<'EOF'
node_modules
dist
.next
*.tsbuildinfo
.env
coverage
EOF

write .gitattributes <<'EOF'
* text=auto eol=lf
EOF

write .dockerignore <<'EOF'
node_modules
**/node_modules
**/dist
**/.next
.git
.env
EOF

write .prettierrc <<'EOF'
{ "singleQuote": true, "trailingComma": "all", "printWidth": 100 }
EOF

# O compose já traz defaults; o .env é OPCIONAL (só para sobrescrever).
write .env.example <<'EOF'
# Opcional: copie para .env para sobrescrever os defaults do docker-compose.yml
PAGFACIL_WEBHOOK_SECRET=troque-este-segredo
EOF

# Imagem única de backend (api, worker, migrate) e também usada pelo web.
# Estágio único de propósito: evita o COPY gigante de node_modules entre estágios.
write docker/node.Dockerfile <<'EOF'
FROM node:22-slim
RUN apt-get update -y \
 && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /repo

# Manifests primeiro: aproveita o cache do npm ci
COPY package.json package-lock.json tsconfig.base.json ./
COPY apps/api/package.json apps/api/
COPY apps/worker/package.json apps/worker/
COPY apps/web/package.json apps/web/
COPY packages/core/package.json packages/core/
COPY packages/infra/package.json packages/infra/
RUN npm ci

COPY . .

ARG BUILD_TARGET=backend
ARG NEXT_PUBLIC_API_URL=http://localhost:3001
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL

RUN npm run db:generate && npm run build:packages && \
    if [ "$BUILD_TARGET" = "web" ]; then \
      npm run build -w @tickteira/web; \
    else \
      npm run build:backend; \
    fi

ENV NODE_ENV=production
EOF

write docker-compose.yml <<'EOF'
name: tickteira

# Defaults embutidos: `docker compose up --build` funciona sem .env.
x-env: &env
  DATABASE_URL: postgresql://tickteira:tickteira@postgres:5432/tickteira?schema=public
  REDIS_URL: redis://redis:6379
  SMTP_HOST: mailpit
  SMTP_PORT: "1025"
  MAIL_FROM: ingressos@tickteira.local
  PAGFACIL_WEBHOOK_SECRET: ${PAGFACIL_WEBHOOK_SECRET:-dev-secret-change-me}
  API_PORT: "3001"

services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: tickteira
      POSTGRES_PASSWORD: tickteira
      POSTGRES_DB: tickteira
    ports: ["5433:5432"]
    volumes: [pgdata:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U tickteira -d tickteira"]
      interval: 3s
      timeout: 3s
      retries: 20

  redis:
    image: redis:7-alpine
    command: ["redis-server", "--appendonly", "yes"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 3s
      timeout: 3s
      retries: 20

  mailpit:
    image: axllent/mailpit
    ports: ["8025:8025"]   # UI dos e-mails

  # Só o api faz build; migrate e worker reaproveitam a mesma imagem.
  api:
    build:
      context: .
      dockerfile: docker/node.Dockerfile
      args: { BUILD_TARGET: backend }
    image: tickteira-backend
    environment: *env
    command: node apps/api/dist/main.js
    ports: ["3001:3001"]
    depends_on:
      migrate: { condition: service_completed_successfully }
      redis: { condition: service_healthy }
    healthcheck:
      test: ["CMD", "node", "-e", "fetch('http://localhost:3001/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
      interval: 5s
      timeout: 5s
      retries: 20
      start_period: 10s

  migrate:
    image: tickteira-backend
    pull_policy: never
    environment: *env
    command: sh -c "npm run db:migrate && npm run db:seed"
    restart: "no"
    depends_on:
      postgres: { condition: service_healthy }

  worker:
    image: tickteira-backend
    pull_policy: never
    environment: *env
    command: node apps/worker/dist/main.js
    deploy: { replicas: 3 }   # prova o requisito de múltiplos workers
    depends_on:
      migrate: { condition: service_completed_successfully }
      redis: { condition: service_healthy }

  web:
    build:
      context: .
      dockerfile: docker/node.Dockerfile
      args:
        BUILD_TARGET: web
        NEXT_PUBLIC_API_URL: http://localhost:3001
    command: npm run start -w @tickteira/web
    ports: ["3000:3000"]
    depends_on:
      api: { condition: service_healthy }

volumes:
  pgdata:
EOF

# =============================================================================
# 2. packages/core  — DOMÍNIO + APLICAÇÃO (sem Nest, Prisma, BullMQ)
# =============================================================================
write packages/core/package.json <<'EOF'
{
  "name": "@tickteira/core",
  "version": "0.0.0",
  "private": true,
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc -p tsconfig.json"
  }
}
EOF
write packages/core/tsconfig.json <<'EOF'
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": { "outDir": "dist", "rootDir": "src" },
  "include": ["src"]
}
EOF

# ---- shared kernel ----------------------------------------------------------
write packages/core/src/shared/contracts/use-case.contract.ts <<'EOF'
export interface UseCase<Input, Output> {
  execute(input: Input): Promise<Output>;
}
EOF
write packages/core/src/shared/contracts/unit-of-work.contract.ts <<'EOF'
/** Executa o trabalho numa única transação atômica. */
export interface UnitOfWork {
  run<T>(work: () => Promise<T>): Promise<T>;
}
EOF
write packages/core/src/shared/contracts/clock.contract.ts <<'EOF'
export interface Clock {
  now(): Date;
}
EOF
write packages/core/src/shared/errors/domain.error.ts <<'EOF'
export abstract class DomainError extends Error {
  abstract readonly code: string;
  constructor(message: string) {
    super(message);
    this.name = new.target.name;
  }
}
EOF
write packages/core/src/shared/constants/queue-names.ts <<'EOF'
export const QUEUES = {
  PAYMENT_EVENTS: 'payments.events',
  EMAIL_DELIVERY: 'notifications.email',
} as const;
EOF

# ---- payments ---------------------------------------------------------------
P=packages/core/src/payments
write $P/domain/types/payment-status.type.ts <<'EOF'
export const PaymentStatus = {
  PENDING: 'PENDING',
  APPROVED: 'APPROVED',
  REFUSED: 'REFUSED',
  REFUNDED: 'REFUNDED',
  CHARGEBACK: 'CHARGEBACK',
} as const;
export type PaymentStatus = (typeof PaymentStatus)[keyof typeof PaymentStatus];
EOF
write $P/domain/types/payment-event-type.type.ts <<'EOF'
export const PaymentEventType = {
  APPROVED: 'payment.approved',
  REFUSED: 'payment.refused',
  REFUNDED: 'payment.refunded',
  CHARGEBACK: 'payment.chargeback',
} as const;
export type PaymentEventType = (typeof PaymentEventType)[keyof typeof PaymentEventType];
EOF
write $P/domain/types/webhook-event-status.type.ts <<'EOF'
export const WebhookEventStatus = {
  RECEIVED: 'RECEIVED',
  PROCESSED: 'PROCESSED',
  UNMATCHED: 'UNMATCHED',
  FAILED: 'FAILED',
} as const;
export type WebhookEventStatus = (typeof WebhookEventStatus)[keyof typeof WebhookEventStatus];
EOF
write $P/domain/entities/payment.entity.ts <<'EOF'
import { PaymentStatus } from '../types/payment-status.type';

export interface Payment {
  id: string;
  providerPaymentId: string;
  orderId: string;
  amountCents: number;
  status: PaymentStatus;
}
EOF
write $P/domain/entities/webhook-event.entity.ts <<'EOF'
import { PaymentEventType } from '../types/payment-event-type.type';
import { WebhookEventStatus } from '../types/webhook-event-status.type';

export interface WebhookEvent {
  eventId: string;
  type: PaymentEventType;
  payload: unknown;
  occurredAt: Date;
  status: WebhookEventStatus;
  attempts: number;
}
EOF
write $P/domain/contracts/signature-verifier.contract.ts <<'EOF'
export interface SignatureVerifier {
  /** Valida HMAC-SHA256 sobre o corpo CRU (bytes originais). */
  verify(rawBody: Buffer, signature: string): boolean;
}
EOF
write $P/domain/contracts/webhook-event.repository.contract.ts <<'EOF'
import { WebhookEvent } from '../entities/webhook-event.entity';

export interface WebhookEventRepository {
  /** @returns true se inseriu; false se o event_id já existia (duplicado). */
  insertIfAbsent(event: WebhookEvent): Promise<boolean>;
  findStuck(olderThan: Date, limit: number): Promise<WebhookEvent[]>;
  markProcessed(eventId: string): Promise<void>;
  markFailed(eventId: string, reason: string): Promise<void>;
}
EOF
write $P/domain/contracts/payment.repository.contract.ts <<'EOF'
import { Payment } from '../entities/payment.entity';

export interface PaymentRepository {
  /** Busca com lock pessimista (SELECT ... FOR UPDATE). Só dentro de UnitOfWork. */
  findByProviderIdForUpdate(providerPaymentId: string): Promise<Payment | null>;
  save(payment: Payment): Promise<void>;
}
EOF
write $P/domain/contracts/payment-event-queue.contract.ts <<'EOF'
export interface PaymentEventQueue {
  /** Deduplica por eventId (jobId). */
  enqueue(eventId: string): Promise<void>;
}
EOF
write $P/domain/errors/invalid-signature.error.ts <<'EOF'
import { DomainError } from '../../../shared/errors/domain.error';

export class InvalidSignatureError extends DomainError {
  readonly code = 'INVALID_SIGNATURE';
  constructor() {
    super('Assinatura do webhook inválida');
  }
}
EOF
write $P/domain/errors/amount-mismatch.error.ts <<'EOF'
import { DomainError } from '../../../shared/errors/domain.error';

export class AmountMismatchError extends DomainError {
  readonly code = 'AMOUNT_MISMATCH';
  constructor(expected: number, received: number) {
    super(`Valor esperado ${expected}, recebido ${received}`);
  }
}
EOF
# Regra central: estorno/chargeback SEMPRE vencem, independente da ordem de chegada.
write $P/domain/services/payment-state-machine.ts <<'EOF'
import { PaymentEventType } from '../types/payment-event-type.type';
import { PaymentStatus } from '../types/payment-status.type';

const ABSORBING: PaymentStatus[] = [PaymentStatus.REFUNDED, PaymentStatus.CHARGEBACK];

export class PaymentStateMachine {
  next(current: PaymentStatus, event: PaymentEventType): PaymentStatus {
    if (ABSORBING.includes(current)) return current; // estado final: nada o desfaz
    switch (event) {
      case PaymentEventType.REFUNDED:
        return PaymentStatus.REFUNDED;
      case PaymentEventType.CHARGEBACK:
        return PaymentStatus.CHARGEBACK;
      case PaymentEventType.APPROVED:
        return current === PaymentStatus.PENDING ? PaymentStatus.APPROVED : current;
      case PaymentEventType.REFUSED:
        return current === PaymentStatus.PENDING ? PaymentStatus.REFUSED : current;
    }
  }
}
EOF
write $P/application/dtos/webhook-payload.dto.ts <<'EOF'
import { PaymentEventType } from '../../domain/types/payment-event-type.type';

export interface WebhookPayload {
  event_id: string;
  event_type: PaymentEventType;
  created_at: string;
  data: {
    payment_id: string;
    order_reference: string;
    amount_cents: number;
    method: string;
  };
}
EOF
usecase $P/application/use-cases/receive-webhook.use-case.ts ReceiveWebhook
usecase $P/application/use-cases/process-payment-event.use-case.ts ProcessPaymentEvent
usecase $P/application/use-cases/requeue-stuck-events.use-case.ts RequeueStuckEvents

# ---- ordering ---------------------------------------------------------------
O=packages/core/src/ordering
write $O/domain/types/order-status.type.ts <<'EOF'
export const OrderStatus = {
  PENDING_PAYMENT: 'PENDING_PAYMENT',
  CONFIRMED: 'CONFIRMED',
  REFUNDED: 'REFUNDED',
  CHARGEBACK: 'CHARGEBACK',
  EXPIRED: 'EXPIRED',
  REQUIRES_REVIEW: 'REQUIRES_REVIEW',
} as const;
export type OrderStatus = (typeof OrderStatus)[keyof typeof OrderStatus];
EOF
write $O/domain/entities/order.entity.ts <<'EOF'
import { OrderStatus } from '../types/order-status.type';

export interface OrderItem {
  sectorId: string;
  quantity: number;
  unitPriceCents: number;
}

export interface Order {
  id: string;
  reference: string; // ex.: TKT-000412
  buyerEmail: string;
  status: OrderStatus;
  totalCents: number;
  items: OrderItem[];
  expiresAt: Date;
}
EOF
write $O/domain/contracts/order.repository.contract.ts <<'EOF'
import { Order } from '../entities/order.entity';

export interface OrderRepository {
  create(order: Order): Promise<void>;
  findByReferenceForUpdate(reference: string): Promise<Order | null>;
  save(order: Order): Promise<void>;
}
EOF
write $O/application/dtos/create-order.dto.ts <<'EOF'
export interface CreateOrderDto {
  buyerEmail: string;
  items: { sectorId: string; quantity: number }[];
}
EOF
usecase $O/application/use-cases/create-order.use-case.ts CreateOrder
usecase $O/application/use-cases/confirm-order.use-case.ts ConfirmOrder

# ---- ticketing --------------------------------------------------------------
T=packages/core/src/ticketing
write $T/domain/types/ticket-status.type.ts <<'EOF'
export const TicketStatus = {
  ISSUED: 'ISSUED',
  VOIDED: 'VOIDED',
  USED: 'USED',
} as const;
export type TicketStatus = (typeof TicketStatus)[keyof typeof TicketStatus];
EOF
write $T/domain/entities/ticket.entity.ts <<'EOF'
import { TicketStatus } from '../types/ticket-status.type';

export interface Ticket {
  id: string;
  orderId: string;
  sectorId: string;
  code: string; // conteúdo do QR
  status: TicketStatus;
  issuedAt: Date;
  voidedAt: Date | null;
}
EOF
write $T/domain/contracts/sector-inventory.repository.contract.ts <<'EOF'
export interface SectorInventoryRepository {
  /** Reserva atômica: UPDATE ... WHERE allocated + qty <= capacity. false = esgotado. */
  tryAllocate(sectorId: string, quantity: number): Promise<boolean>;
}
EOF
write $T/domain/contracts/ticket.repository.contract.ts <<'EOF'
import { Ticket } from '../entities/ticket.entity';

export interface TicketRepository {
  saveMany(tickets: Ticket[]): Promise<void>;
  findByOrderId(orderId: string): Promise<Ticket[]>;
  findByCode(code: string): Promise<Ticket | null>;
  voidByOrderId(orderId: string, at: Date): Promise<void>;
}
EOF
write $T/domain/contracts/qr-code-generator.contract.ts <<'EOF'
export interface QrCodeGenerator {
  /** @returns imagem em data URI (PNG) para o conteúdo informado. */
  toDataUri(content: string): Promise<string>;
}
EOF
usecase $T/application/use-cases/issue-tickets.use-case.ts IssueTickets
usecase $T/application/use-cases/void-tickets.use-case.ts VoidTickets
usecase $T/application/use-cases/validate-ticket.use-case.ts ValidateTicket

# ---- notifications ----------------------------------------------------------
N=packages/core/src/notifications
write $N/domain/types/email-delivery-status.type.ts <<'EOF'
export const EmailDeliveryStatus = {
  PENDING: 'PENDING',
  SENT: 'SENT',
  FAILED: 'FAILED',
} as const;
export type EmailDeliveryStatus = (typeof EmailDeliveryStatus)[keyof typeof EmailDeliveryStatus];
EOF
write $N/domain/entities/email-delivery.entity.ts <<'EOF'
import { EmailDeliveryStatus } from '../types/email-delivery-status.type';

export interface EmailDelivery {
  id: string;
  orderId: string;
  recipient: string;
  status: EmailDeliveryStatus;
  attempts: number;
  lastError: string | null;
  sentAt: Date | null;
}
EOF
write $N/domain/contracts/email-delivery.repository.contract.ts <<'EOF'
import { EmailDelivery } from '../entities/email-delivery.entity';

export interface EmailDeliveryRepository {
  create(delivery: EmailDelivery): Promise<void>;
  findFailed(): Promise<EmailDelivery[]>;
  /** Transição atômica FAILED -> PENDING. false se outro já a fez (duplo clique). */
  tryRequeue(id: string): Promise<boolean>;
  markSent(id: string, at: Date): Promise<void>;
  markFailed(id: string, error: string): Promise<void>;
}
EOF
write $N/domain/contracts/mail-sender.contract.ts <<'EOF'
export interface MailMessage {
  to: string;
  subject: string;
  html: string;
}

export interface MailSender {
  send(message: MailMessage): Promise<void>;
}
EOF
write $N/domain/contracts/email-queue.contract.ts <<'EOF'
export interface EmailQueue {
  enqueue(deliveryId: string): Promise<void>;
}
EOF
usecase $N/application/use-cases/send-ticket-email.use-case.ts SendTicketEmail
usecase $N/application/use-cases/list-failed-emails.use-case.ts ListFailedEmails
usecase $N/application/use-cases/resend-email.use-case.ts ResendEmail


# =============================================================================
# 3. packages/infra — ADAPTERS que implementam os contratos do core
# =============================================================================
write packages/infra/package.json <<'EOF'
{
  "name": "@tickteira/infra",
  "version": "0.0.0",
  "private": true,
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc -p tsconfig.json"
  },
  "dependencies": {
    "@prisma/client": "^6.0.0",
    "@tickteira/core": "*",
    "bullmq": "^5.0.0",
    "ioredis": "^5.4.0"
  }
}
EOF
write packages/infra/tsconfig.json <<'EOF'
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": { "outDir": "dist", "rootDir": "src" },
  "include": ["src"]
}
EOF
write packages/infra/src/index.ts <<'EOF'
export { PrismaClient } from '@prisma/client';
export { Redis } from 'ioredis';
export * from './persistence/prisma.factory';
export * from './queue/redis.factory';
export * from './security/hmac-signature.verifier';
export * from './clock/system.clock';
EOF
write packages/infra/src/persistence/prisma.factory.ts <<'EOF'
import { PrismaClient } from '@prisma/client';

export function createPrismaClient(): PrismaClient {
  return new PrismaClient();
}
EOF
write packages/infra/src/queue/redis.factory.ts <<'EOF'
import { Redis } from 'ioredis';

export function createRedis(url: string): Redis {
  return new Redis(url);
}

/** Opções de conexão para BullMQ (maxRetriesPerRequest null é exigido pelos Workers). */
export function redisConnectionFromUrl(url: string) {
  const parsed = new URL(url);
  return {
    host: parsed.hostname,
    port: Number(parsed.port || 6379),
    maxRetriesPerRequest: null as null,
  };
}
EOF
write packages/infra/src/security/hmac-signature.verifier.ts <<'EOF'
import { createHmac, timingSafeEqual } from 'node:crypto';
import { SignatureVerifier } from '@tickteira/core';

export class HmacSignatureVerifier implements SignatureVerifier {
  constructor(private readonly secret: string) {}

  verify(rawBody: Buffer, signature: string): boolean {
    const expected = createHmac('sha256', this.secret).update(rawBody).digest();
    const received = Buffer.from(signature, 'hex');
    return received.length === expected.length && timingSafeEqual(received, expected);
  }
}
EOF
write packages/infra/src/clock/system.clock.ts <<'EOF'
import { Clock } from '@tickteira/core';

export class SystemClock implements Clock {
  now(): Date {
    return new Date();
  }
}
EOF

# ---- Prisma: schema, migration inicial (com CHECK de capacidade) e seed ----
write packages/infra/prisma/schema.prisma <<'EOF'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Event {
  id       String   @id @default(uuid())
  name     String
  startsAt DateTime @map("starts_at")
  sectors  Sector[]

  @@map("events")
}

model Sector {
  id         String      @id @default(uuid())
  eventId    String      @map("event_id")
  name       String
  capacity   Int
  allocated  Int         @default(0)
  priceCents Int         @map("price_cents")
  event      Event       @relation(fields: [eventId], references: [id])
  orderItems OrderItem[]
  tickets    Ticket[]

  @@map("sectors")
}

model Order {
  id              String          @id @default(uuid())
  reference       String          @unique
  buyerEmail      String          @map("buyer_email")
  status          String
  totalCents      Int             @map("total_cents")
  expiresAt       DateTime        @map("expires_at")
  createdAt       DateTime        @default(now()) @map("created_at")
  items           OrderItem[]
  payments        Payment[]
  tickets         Ticket[]
  emailDeliveries EmailDelivery[]

  @@map("orders")
}

model OrderItem {
  id             String @id @default(uuid())
  orderId        String @map("order_id")
  sectorId       String @map("sector_id")
  quantity       Int
  unitPriceCents Int    @map("unit_price_cents")
  order          Order  @relation(fields: [orderId], references: [id])
  sector         Sector @relation(fields: [sectorId], references: [id])

  @@map("order_items")
}

model Payment {
  id                String   @id @default(uuid())
  providerPaymentId String   @unique @map("provider_payment_id")
  orderId           String   @map("order_id")
  status            String
  amountCents       Int      @map("amount_cents")
  createdAt         DateTime @default(now()) @map("created_at")
  order             Order    @relation(fields: [orderId], references: [id])

  @@index([orderId])
  @@map("payments")
}

model WebhookEvent {
  eventId    String   @id @map("event_id")
  type       String
  payload    Json
  occurredAt DateTime @map("occurred_at")
  status     String   @default("RECEIVED")
  attempts   Int      @default(0)
  error      String?
  receivedAt DateTime @default(now()) @map("received_at")

  @@index([status, receivedAt])
  @@map("webhook_events")
}

model Ticket {
  id       String    @id @default(uuid())
  orderId  String    @map("order_id")
  sectorId String    @map("sector_id")
  code     String    @unique
  status   String    @default("ISSUED")
  issuedAt DateTime  @default(now()) @map("issued_at")
  voidedAt DateTime? @map("voided_at")
  order    Order     @relation(fields: [orderId], references: [id])
  sector   Sector    @relation(fields: [sectorId], references: [id])

  @@index([orderId])
  @@map("tickets")
}

model EmailDelivery {
  id        String    @id @default(uuid())
  orderId   String    @map("order_id")
  recipient String
  status    String    @default("PENDING")
  attempts  Int       @default(0)
  lastError String?   @map("last_error")
  sentAt    DateTime? @map("sent_at")
  createdAt DateTime  @default(now()) @map("created_at")
  order     Order     @relation(fields: [orderId], references: [id])

  @@index([status])
  @@map("email_deliveries")
}
EOF

write packages/infra/prisma/migrations/migration_lock.toml <<'EOF'
# Please do not edit this file manually
provider = "postgresql"
EOF

write packages/infra/prisma/migrations/20260919000000_init/migration.sql <<'EOF'
-- CreateTable
CREATE TABLE "events" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "starts_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sectors" (
    "id" TEXT NOT NULL,
    "event_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "capacity" INTEGER NOT NULL,
    "allocated" INTEGER NOT NULL DEFAULT 0,
    "price_cents" INTEGER NOT NULL,

    CONSTRAINT "sectors_pkey" PRIMARY KEY ("id"),
    -- Última linha de defesa: o banco recusa vender além da capacidade.
    CONSTRAINT "sectors_allocated_within_capacity" CHECK ("allocated" >= 0 AND "allocated" <= "capacity")
);

-- CreateTable
CREATE TABLE "orders" (
    "id" TEXT NOT NULL,
    "reference" TEXT NOT NULL,
    "buyer_email" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "total_cents" INTEGER NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_items" (
    "id" TEXT NOT NULL,
    "order_id" TEXT NOT NULL,
    "sector_id" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL,
    "unit_price_cents" INTEGER NOT NULL,

    CONSTRAINT "order_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payments" (
    "id" TEXT NOT NULL,
    "provider_payment_id" TEXT NOT NULL,
    "order_id" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "amount_cents" INTEGER NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "webhook_events" (
    "event_id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "occurred_at" TIMESTAMP(3) NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'RECEIVED',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "error" TEXT,
    "received_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "webhook_events_pkey" PRIMARY KEY ("event_id")
);

-- CreateTable
CREATE TABLE "tickets" (
    "id" TEXT NOT NULL,
    "order_id" TEXT NOT NULL,
    "sector_id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'ISSUED',
    "issued_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "voided_at" TIMESTAMP(3),

    CONSTRAINT "tickets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "email_deliveries" (
    "id" TEXT NOT NULL,
    "order_id" TEXT NOT NULL,
    "recipient" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "last_error" TEXT,
    "sent_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "email_deliveries_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "orders_reference_key" ON "orders"("reference");

-- CreateIndex
CREATE UNIQUE INDEX "payments_provider_payment_id_key" ON "payments"("provider_payment_id");

-- CreateIndex
CREATE INDEX "payments_order_id_idx" ON "payments"("order_id");

-- CreateIndex
CREATE INDEX "webhook_events_status_received_at_idx" ON "webhook_events"("status", "received_at");

-- CreateIndex
CREATE UNIQUE INDEX "tickets_code_key" ON "tickets"("code");

-- CreateIndex
CREATE INDEX "tickets_order_id_idx" ON "tickets"("order_id");

-- CreateIndex
CREATE INDEX "email_deliveries_status_idx" ON "email_deliveries"("status");

-- AddForeignKey
ALTER TABLE "sectors" ADD CONSTRAINT "sectors_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_sector_id_fkey" FOREIGN KEY ("sector_id") REFERENCES "sectors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tickets" ADD CONSTRAINT "tickets_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tickets" ADD CONSTRAINT "tickets_sector_id_fkey" FOREIGN KEY ("sector_id") REFERENCES "sectors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "email_deliveries" ADD CONSTRAINT "email_deliveries_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EOF

# Seed em JS puro (CommonJS): não depende de ts-node nem de tsconfig. Idempotente.
write packages/infra/prisma/seed.js <<'EOF'
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();
const EVENT_ID = 'evt-show-28';

const SECTORS = [
  { id: 'sec-pista', name: 'Pista', capacity: 6000, priceCents: 12000 },
  { id: 'sec-camarote', name: 'Camarote', capacity: 1500, priceCents: 24000 },
  { id: 'sec-vip', name: 'VIP', capacity: 500, priceCents: 48000 },
  // Setor minúsculo para o cenário de corrida de capacidade (3 vagas, 10 compradores)
  { id: 'sec-teste', name: 'Setor de teste', capacity: 3, priceCents: 1000 },
];

async function main() {
  await prisma.event.upsert({
    where: { id: EVENT_ID },
    update: {},
    create: { id: EVENT_ID, name: 'Show do dia 28', startsAt: new Date('2026-09-28T22:00:00Z') },
  });
  for (const s of SECTORS) {
    await prisma.sector.upsert({
      where: { id: s.id },
      update: {}, // nunca zera "allocated" em re-execuções
      create: { ...s, eventId: EVENT_ID },
    });
  }
  console.log('seed ok: 1 evento e ' + SECTORS.length + ' setores');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
EOF

# =============================================================================
# 4. apps/api — HTTP fino (controller -> use case). Hoje: GET /health
# =============================================================================
write apps/api/package.json <<'EOF'
{
  "name": "@tickteira/api",
  "version": "0.0.0",
  "private": true,
  "scripts": {
    "build": "tsc -p tsconfig.json"
  },
  "dependencies": {
    "@nestjs/common": "^11.0.0",
    "@nestjs/core": "^11.0.0",
    "@nestjs/platform-express": "^11.0.0",
    "@tickteira/core": "*",
    "@tickteira/infra": "*",
    "reflect-metadata": "^0.2.2",
    "rxjs": "^7.8.1"
  }
}
EOF
write apps/api/tsconfig.json <<'EOF'
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src",
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true
  },
  "include": ["src"]
}
EOF
write apps/api/src/main.ts <<'EOF'
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  // rawBody: true é obrigatório — o HMAC é calculado sobre os bytes originais.
  const app = await NestFactory.create(AppModule, { rawBody: true });
  app.enableCors();
  app.enableShutdownHooks();
  await app.listen(Number(process.env.API_PORT ?? 3001), '0.0.0.0');
}
void bootstrap();
EOF
write apps/api/src/app.module.ts <<'EOF'
import { Module } from '@nestjs/common';
import { InfraModule } from './shared/infra.module';
import { HealthModule } from './modules/health/health.module';
import { OrdersModule } from './modules/orders/orders.module';
import { SupportModule } from './modules/support/support.module';
import { TicketsModule } from './modules/tickets/tickets.module';
import { WebhooksModule } from './modules/webhooks/webhooks.module';

@Module({
  imports: [
    InfraModule,
    HealthModule,
    OrdersModule,
    WebhooksModule,
    TicketsModule,
    SupportModule,
  ],
})
export class AppModule {}
EOF
write apps/api/src/shared/di-tokens.ts <<'EOF'
// Tokens de injeção: ligam contratos (interfaces) às implementações do infra.
export const TOKENS = {
  Prisma: Symbol('Prisma'),
  Redis: Symbol('Redis'),
} as const;
EOF
write apps/api/src/shared/infra.module.ts <<'EOF'
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
EOF
write apps/api/src/modules/health/health.controller.ts <<'EOF'
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
EOF
write apps/api/src/modules/health/health.module.ts <<'EOF'
import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';

@Module({ controllers: [HealthController] })
export class HealthModule {}
EOF
for m in orders webhooks tickets support; do
  cls="$(echo "${m:0:1}" | tr a-z A-Z)${m:1}"
  write apps/api/src/modules/$m/$m.module.ts <<EOF
import { Module } from '@nestjs/common';

// Controllers só traduzem HTTP -> UseCase.execute(). Nenhuma regra de negócio aqui.
@Module({ controllers: [], providers: [] })
export class ${cls}Module {}
EOF
done

# =============================================================================
# 5. apps/worker — consumidores de fila finos (job -> use case)
# =============================================================================
write apps/worker/package.json <<'EOF'
{
  "name": "@tickteira/worker",
  "version": "0.0.0",
  "private": true,
  "scripts": {
    "build": "tsc -p tsconfig.json"
  },
  "dependencies": {
    "@nestjs/common": "^11.0.0",
    "@nestjs/core": "^11.0.0",
    "@tickteira/core": "*",
    "@tickteira/infra": "*",
    "bullmq": "^5.0.0",
    "reflect-metadata": "^0.2.2",
    "rxjs": "^7.8.1"
  }
}
EOF
write apps/worker/tsconfig.json <<'EOF'
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src",
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true
  },
  "include": ["src"]
}
EOF
write apps/worker/src/main.ts <<'EOF'
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { WorkerModule } from './worker.module';

async function bootstrap() {
  // Sem HTTP: apenas consumidores. Réplicas escalam via docker compose.
  const app = await NestFactory.createApplicationContext(WorkerModule);
  app.enableShutdownHooks();
}
void bootstrap();
EOF
write apps/worker/src/worker.module.ts <<'EOF'
import { Module } from '@nestjs/common';
import { EmailConsumer } from './consumers/email/email.consumer';
import { PaymentEventsConsumer } from './consumers/payment/payment-events.consumer';

@Module({ providers: [PaymentEventsConsumer, EmailConsumer] })
export class WorkerModule {}
EOF
write apps/worker/src/consumers/payment/payment-events.consumer.ts <<'EOF'
import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Job, Worker } from 'bullmq';
import { QUEUES } from '@tickteira/core';
import { redisConnectionFromUrl } from '@tickteira/infra';

// Consumer fino: traduz o job em uma chamada de UseCase (ProcessPaymentEvent).
@Injectable()
export class PaymentEventsConsumer implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PaymentEventsConsumer.name);
  private worker?: Worker;

  onModuleInit(): void {
    const url = process.env.REDIS_URL ?? 'redis://localhost:6379';
    this.worker = new Worker(QUEUES.PAYMENT_EVENTS, (job) => this.handle(job), {
      connection: redisConnectionFromUrl(url),
      concurrency: 10,
    });
    this.logger.log(`consumindo ${QUEUES.PAYMENT_EVENTS}`);
  }

  private async handle(job: Job): Promise<void> {
    this.logger.log(`job ${job.id} recebido (TODO: ProcessPaymentEventUseCase)`);
  }

  async onModuleDestroy(): Promise<void> {
    await this.worker?.close();
  }
}
EOF
write apps/worker/src/consumers/email/email.consumer.ts <<'EOF'
import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Job, Worker } from 'bullmq';
import { QUEUES } from '@tickteira/core';
import { redisConnectionFromUrl } from '@tickteira/infra';

// Consumer fino: traduz o job em uma chamada de UseCase (SendTicketEmail).
@Injectable()
export class EmailConsumer implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(EmailConsumer.name);
  private worker?: Worker;

  onModuleInit(): void {
    const url = process.env.REDIS_URL ?? 'redis://localhost:6379';
    this.worker = new Worker(QUEUES.EMAIL_DELIVERY, (job) => this.handle(job), {
      connection: redisConnectionFromUrl(url),
      concurrency: 5,
    });
    this.logger.log(`consumindo ${QUEUES.EMAIL_DELIVERY}`);
  }

  private async handle(job: Job): Promise<void> {
    this.logger.log(`job ${job.id} recebido (TODO: SendTicketEmailUseCase)`);
  }

  async onModuleDestroy(): Promise<void> {
    await this.worker?.close();
  }
}
EOF

# =============================================================================
# 6. apps/web — tela do suporte (Next.js, App Router)
# =============================================================================
write apps/web/package.json <<'EOF'
{
  "name": "@tickteira/web",
  "version": "0.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev -p 3000",
    "build": "next build",
    "start": "next start -H 0.0.0.0 -p 3000"
  },
  "dependencies": {
    "next": "^15.0.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0"
  }
}
EOF
write apps/web/next.config.mjs <<'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {};
export default nextConfig;
EOF
write apps/web/tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }]
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF
write apps/web/src/types/email-delivery.type.ts <<'EOF'
export interface EmailDeliveryView {
  id: string;
  orderReference: string;
  recipient: string;
  status: 'PENDING' | 'SENT' | 'FAILED';
  attempts: number;
  lastError: string | null;
}
EOF
write apps/web/src/services/support.service.ts <<'EOF'
import type { EmailDeliveryView } from '../types/email-delivery.type';

const API = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001';

export const supportService = {
  async listFailedEmails(): Promise<EmailDeliveryView[]> {
    const res = await fetch(`${API}/support/emails?status=FAILED`, { cache: 'no-store' });
    if (!res.ok) throw new Error('Falha ao listar e-mails');
    return res.json();
  },
  async resend(id: string): Promise<void> {
    const res = await fetch(`${API}/support/emails/${id}/resend`, { method: 'POST' });
    if (!res.ok) throw new Error('Falha ao reenviar e-mail');
  },
};
EOF
write apps/web/src/app/layout.tsx <<'EOF'
import type { ReactNode } from 'react';

export const metadata = { title: 'Tickteira — Suporte' };

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="pt-BR">
      <body style={{ fontFamily: 'system-ui, sans-serif', margin: 24 }}>{children}</body>
    </html>
  );
}
EOF
write apps/web/src/app/page.tsx <<'EOF'
import Link from 'next/link';

export default function Home() {
  return (
    <main>
      <h1>Tickteira</h1>
      <p>
        <Link href="/support/emails">Suporte: e-mails com falha</Link>
      </p>
    </main>
  );
}
EOF
write apps/web/src/app/support/emails/page.tsx <<'EOF'
'use client';

import { useCallback, useEffect, useState } from 'react';
import { supportService } from '../../../services/support.service';
import type { EmailDeliveryView } from '../../../types/email-delivery.type';

export default function SupportEmailsPage() {
  const [items, setItems] = useState<EmailDeliveryView[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setItems(await supportService.listFailedEmails());
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erro inesperado');
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  async function resend(id: string) {
    setBusyId(id);
    try {
      await supportService.resend(id);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erro inesperado');
    } finally {
      setBusyId(null);
    }
  }

  return (
    <main>
      <h1>E-mails com falha</h1>
      {error && <p style={{ color: 'crimson' }}>{error}</p>}
      {!error && items.length === 0 && <p>Nenhum envio com falha.</p>}
      {items.length > 0 && (
        <table cellPadding={8} style={{ borderCollapse: 'collapse' }}>
          <thead>
            <tr>
              <th align="left">Pedido</th>
              <th align="left">Destinatário</th>
              <th align="left">Tentativas</th>
              <th align="left">Erro</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {items.map((item) => (
              <tr key={item.id}>
                <td>{item.orderReference}</td>
                <td>{item.recipient}</td>
                <td>{item.attempts}</td>
                <td>{item.lastError}</td>
                <td>
                  <button disabled={busyId === item.id} onClick={() => resend(item.id)}>
                    {busyId === item.id ? 'Reenviando…' : 'Reenviar'}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </main>
  );
}
EOF

# =============================================================================
# 7. scripts — simulador de webhooks + guarda de arquitetura
# =============================================================================
write scripts/webhook-simulator/scenario.contract.ts <<'EOF'
export interface Scenario {
  name: string;
  run(ctx: { post: (body: object) => Promise<Response> }): Promise<void>;
}
EOF
write scripts/webhook-simulator/sign.ts <<'EOF'
import { createHmac } from 'node:crypto';

export function sign(rawBody: string, secret: string): string {
  return createHmac('sha256', secret).update(rawBody).digest('hex');
}
EOF
write scripts/webhook-simulator/index.ts <<'EOF'
// TODO: carregar ./scenarios/*, montar body, assinar (sign.ts), POST em /webhooks/pagfacil
console.log('simulador: não implementado');
EOF
for s in happy-path duplicate-parallel invalid-signature refunded-before-approved \
         approved-then-refunded chargeback refused capacity-race amount-mismatch \
         unknown-order email-failure worker-crash redis-down burst-500; do
  write scripts/webhook-simulator/scenarios/$s.scenario.ts <<EOF
import { Scenario } from '../scenario.contract';

export const scenario: Scenario = {
  name: '$s',
  async run() {
    throw new Error('cenário $s não implementado');
  },
};
EOF
done

write scripts/check-architecture.sh <<'EOF'
#!/usr/bin/env bash
# Falha se o domínio/aplicação importar framework ou infraestrutura.
set -euo pipefail
if grep -rEn "from '(@nestjs|@prisma|bullmq|ioredis|nodemailer|@tickteira/infra)" packages/core/src; then
  echo "ERRO: packages/core não pode depender de framework ou infra." >&2
  exit 1
fi
echo "Arquitetura OK: core está isolado."
EOF
chmod +x scripts/check-architecture.sh

# =============================================================================
# 8. docs — ADRs e README
# =============================================================================
for adr in 0001-bullmq-vs-rabbitmq 0002-reserva-de-capacidade 0003-eventos-fora-de-ordem 0004-momento-do-email; do
  write docs/adr/$adr.md <<EOF
# ${adr}

- **Status:** aceito
- **Contexto:** …
- **Decisão:** …
- **Alternativas consideradas:** …
- **Consequências (o que perdemos):** …
EOF
done
write docs/architecture.md <<'EOF'
# Arquitetura

Regra de dependência: `apps/* -> packages/infra -> packages/core`. O core não importa ninguém.

```mermaid
flowchart LR
  PagFacil -->|webhook| API
  API -->|INSERT inbox + enqueue| Postgres & Redis
  Redis --> Worker
  Worker -->|UseCases do core| Postgres
  Worker --> Mailpit
  Web --> API
```
EOF
write README.md <<'EOF'
# Tickteira — Desafio Fullstack

## a) Como executar

```bash
docker compose up --build
```

| Serviço | URL |
|---|---|
| Web (suporte) | http://localhost:3000 |
| API | http://localhost:3001 (`GET /health`) |
| Mailpit (e-mails) | http://localhost:8025 |
| Postgres (host) | localhost:5433 (`tickteira`/`tickteira`) |

Migrations e seed rodam sozinhos (serviço `migrate`). O `.env` é opcional: os defaults
estão no `docker-compose.yml`.

## b) Tecnologias e o porquê
## c) Desenho da solução
## d) Modos de falha
## e) Trade-offs
## f) Testes realizados
## g) A decisão do e-mail
## h) O que faria diferente com mais tempo
EOF

# =============================================================================
# 9. Barrel do core (gerado) e .gitkeep nas pastas vazias
# =============================================================================
{
  echo "// GERADO por scaffold — não editar à mão"
  (cd packages/core/src && find . -name '*.ts' ! -name index.ts | sort | sed -E 's|\.ts$||; s|^|export * from "|; s|$|";|')
} >packages/core/src/index.ts
echo "gen   packages/core/src/index.ts"

find . -type d -empty -not -path './node_modules/*' -not -path './.git/*' -exec touch {}/.gitkeep \;

cat <<'EOF'

============================================================
Scaffold concluído. Próximos passos:

  npm install                 # gera o package-lock.json (commite-o)
  npm run db:generate         # gera o Prisma Client
  npm run build:packages
  npm run build:backend       # api + worker compilando
  npm run check:arch

  git add -A && git commit -m "chore: scaffold inicial"
  docker compose up --build

Depois: http://localhost:3001/health deve responder {"status":"ok",...}
============================================================
EOF
