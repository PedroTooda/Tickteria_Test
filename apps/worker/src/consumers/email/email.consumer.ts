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
