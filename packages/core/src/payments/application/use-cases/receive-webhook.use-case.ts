import { UseCase } from '../../../shared/contracts/use-case.contract';
import { SignatureVerifier } from '../../domain/contracts/signature-verifier.contract';
import { WebhookEventRepository } from '../../domain/contracts/webhook-event.repository.contract';
import { PaymentEventQueue } from '../../domain/contracts/payment-event-queue.contract';
import { InvalidSignatureError } from '../../domain/errors/invalid-signature.error';
import { WebhookEventStatus } from '../../domain/types/webhook-event-status.type';
import { WebhookPayload } from '../dtos/webhook-payload.dto';

export interface ReceiveWebhookInput {
  rawBody: Buffer;
  signature: string;
}

export type ReceiveWebhookOutput = void;

export class ReceiveWebhookUseCase implements UseCase<ReceiveWebhookInput, ReceiveWebhookOutput> {
  constructor(
    private readonly signatureVerifier: SignatureVerifier,
    private readonly events: WebhookEventRepository,
    private readonly queue: PaymentEventQueue,
  ) {}

  async execute(input: ReceiveWebhookInput): Promise<void> {
    // Assinatura SEMPRE sobre os bytes crus — nunca sobre o JSON já parseado.
    if (!this.signatureVerifier.verify(input.rawBody, input.signature)) {
      throw new InvalidSignatureError();
    }

    const payload = JSON.parse(input.rawBody.toString('utf8')) as WebhookPayload;

    const inserted = await this.events.insertIfAbsent({
      eventId: payload.event_id,
      type: payload.event_type,
      payload,
      occurredAt: new Date(payload.created_at),
      status: WebhookEventStatus.RECEIVED,
      attempts: 0,
    });

    // Duplicado (a operadora reenviou o mesmo evento): idempotente, não reenfileira.
    if (!inserted) return;

    await this.queue.enqueue(payload.event_id);
  }
}