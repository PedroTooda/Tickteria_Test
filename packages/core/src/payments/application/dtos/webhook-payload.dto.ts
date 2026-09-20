import { PaymentEventType } from '../../domain/types/payment-event-type.type';

export interface WebhookPayload {
  event_id: string;
  event_type: PaymentEventType;
  created_at: string;
  data: {
    payment_id: string;
    order_reference: string;
    amount_cents: number;
    method: string;
  };
}
