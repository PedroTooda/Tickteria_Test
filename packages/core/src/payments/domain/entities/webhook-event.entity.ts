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
