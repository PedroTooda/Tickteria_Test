export const PaymentStatus = {
  PENDING: 'PENDING',
  APPROVED: 'APPROVED',
  REFUSED: 'REFUSED',
  REFUNDED: 'REFUNDED',
  CHARGEBACK: 'CHARGEBACK',
} as const;
export type PaymentStatus = (typeof PaymentStatus)[keyof typeof PaymentStatus];
