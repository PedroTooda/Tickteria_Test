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
