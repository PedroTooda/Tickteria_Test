import { Queue } from 'bullmq';
import { PaymentEventQueue, QUEUES } from '@tickteira/core';
import { redisConnectionFromUrl } from './redis.factory';

export class BullMqPaymentEventQueue implements PaymentEventQueue {
  private readonly queue: Queue;

  constructor(redisUrl: string) {
    this.queue = new Queue(QUEUES.PAYMENT_EVENTS, { connection: redisConnectionFromUrl(redisUrl) });
  }

  async enqueue(eventId: string): Promise<void> {
    // jobId = eventId: segunda camada de proteção, o BullMQ recusa job duplicado com o mesmo id.
    await this.queue.add('payment-event', { eventId }, { jobId: eventId });
  }
}