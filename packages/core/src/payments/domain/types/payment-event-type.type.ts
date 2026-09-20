export const PaymentEventType = {
  APPROVED: 'payment.approved',
  REFUSED: 'payment.refused',
  REFUNDED: 'payment.refunded',
  CHARGEBACK: 'payment.chargeback',
} as const;
export type PaymentEventType = (typeof PaymentEventType)[keyof typeof PaymentEventType];
