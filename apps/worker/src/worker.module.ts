import { Module } from '@nestjs/common';
import { EmailConsumer } from './consumers/email/email.consumer';
import { PaymentEventsConsumer } from './consumers/payment/payment-events.consumer';

@Module({ providers: [PaymentEventsConsumer, EmailConsumer] })
export class WorkerModule {}
