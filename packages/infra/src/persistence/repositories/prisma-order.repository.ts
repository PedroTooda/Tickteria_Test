import { Order, OrderRepository, OrderStatus } from '@tickteira/core';
import { PrismaContext } from '../prisma.context';

export class PrismaOrderRepository implements OrderRepository {
  constructor(private readonly ctx: PrismaContext) {}

  async create(order: Order): Promise<void> {
    await this.ctx.client.order.create({
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

  /** SELECT ... FOR UPDATE: só faz sentido dentro de uma transação (UnitOfWork). */
  async findByReferenceForUpdate(reference: string): Promise<Order | null> {
    const locked = await this.ctx.client.$queryRaw<{ id: string }[]>`
      SELECT id FROM orders WHERE reference = ${reference} FOR UPDATE`;
    const first = locked[0];
    if (!first) return null;

    const row = await this.ctx.client.order.findUnique({
      where: { id: first.id },
      include: { items: true },
    });
    if (!row) return null;

    return {
      id: row.id,
      reference: row.reference,
      buyerEmail: row.buyerEmail,
      status: row.status as OrderStatus,
      totalCents: row.totalCents,
      expiresAt: row.expiresAt,
      items: row.items.map((i) => ({
        sectorId: i.sectorId,
        quantity: i.quantity,
        unitPriceCents: i.unitPriceCents,
      })),
    };
  }

  async save(order: Order): Promise<void> {
    await this.ctx.client.order.update({
      where: { id: order.id },
      data: { status: order.status, totalCents: order.totalCents },
    });
  }
}