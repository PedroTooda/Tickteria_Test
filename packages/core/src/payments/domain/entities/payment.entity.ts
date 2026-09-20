import { PaymentStatus } from '../types/payment-status.type';

export interface Payment {
  id: string;
  providerPaymentId: string;
  orderId: string;
  amountCents: number;
  status: PaymentStatus;
}
