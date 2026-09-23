import { WebhookEvent, WebhookEventRepository } from '@tickteira/core';
import { PrismaContext } from '../prisma.context';

export class PrismaWebhookEventRepository implements WebhookEventRepository {
  constructor(private readonly ctx: PrismaContext) {}

  async insertIfAbsent(event: WebhookEvent): Promise<boolean> {
    try {
      await this.ctx.client.webhookEvent.create({
        data: {
          eventId: event.eventId,
          type: event.type,
          payload: event.payload as object,
          occurredAt: event.occurredAt,
          status: event.status,
          attempts: event.attempts,
        },
      });
      return true;
    } catch (err) {
      // P2002 = violação de índice único: já existe esse event_id, é duplicado.
      if ((err as { code?: string })?.code === 'P2002') return false;
      throw err;
    }
  }

  async findStuck(olderThan: Date, limit: number): Promise<WebhookEvent[]> {
    const rows = await this.ctx.client.webhookEvent.findMany({
      where: { status: 'RECEIVED', receivedAt: { lt: olderThan } },
      take: limit,
    });
    return rows.map((r) => ({
      eventId: r.eventId,
      type: r.type as WebhookEvent['type'],
      payload: r.payload,
      occurredAt: r.occurredAt,
      status: r.status as WebhookEvent['status'],
      attempts: r.attempts,
    }));
  }

  async markProcessed(eventId: string): Promise<void> {
    await this.ctx.client.webhookEvent.update({ where: { eventId }, data: { status: 'PROCESSED' } });
  }

  async markFailed(eventId: string, reason: string): Promise<void> {
    await this.ctx.client.webhookEvent.update({
      where: { eventId },
      data: { status: 'FAILED', error: reason, attempts: { increment: 1 } },
    });
  }
}