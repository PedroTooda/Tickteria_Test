import { Module } from '@nestjs/common';
import { ReceiveWebhookUseCase } from '@tickteira/core';
import { TOKENS } from '../../shared/di-tokens';
import { WebhooksController } from './webhooks.controller';

@Module({
  controllers: [WebhooksController],
  providers: [
    {
      provide: TOKENS.ReceiveWebhookUseCase,
      useFactory: (verifier, events, queue) => new ReceiveWebhookUseCase(verifier, events, queue),
      inject: [TOKENS.SignatureVerifier, TOKENS.WebhookEventRepository, TOKENS.PaymentEventQueue],
    },
  ],
})
export class WebhooksModule {}