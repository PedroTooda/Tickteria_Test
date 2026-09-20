export interface EmailDeliveryView {
  id: string;
  orderReference: string;
  recipient: string;
  status: 'PENDING' | 'SENT' | 'FAILED';
  attempts: number;
  lastError: string | null;
}
