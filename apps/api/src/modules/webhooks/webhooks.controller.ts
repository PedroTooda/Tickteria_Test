import { Controller, Headers, HttpCode, Inject, Post, Req } from '@nestjs/common';
import type { RawBodyRequest } from '@nestjs/common';
import type { Request } from 'express';
import { ReceiveWebhookUseCase } from '@tickteira/core';
import { TOKENS } from '../../shared/di-tokens';

@Controller('webhooks')
export class WebhooksController {
  constructor(
    @Inject(TOKENS.ReceiveWebhookUseCase) private readonly receiveWebhook: ReceiveWebhookUseCase,
  ) {}

  @Post('pagfacil')
  @HttpCode(202)
  async receive(@Req() req: RawBodyRequest<Request>, @Headers('x-webhook-signature') signature: string) {
    await this.receiveWebhook.execute({
      rawBody: req.rawBody ?? Buffer.from(''),
      signature: signature ?? '',
    });
  }
}