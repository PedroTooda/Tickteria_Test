import { EmailDeliveryStatus } from '../types/email-delivery-status.type';

export interface EmailDelivery {
  id: string;
  orderId: string;
  recipient: string;
  status: EmailDeliveryStatus;
  attempts: number;
  lastError: string | null;
  sentAt: Date | null;
}
