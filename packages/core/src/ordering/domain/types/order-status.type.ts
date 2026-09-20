export const OrderStatus = {
  PENDING_PAYMENT: 'PENDING_PAYMENT',
  CONFIRMED: 'CONFIRMED',
  REFUNDED: 'REFUNDED',
  CHARGEBACK: 'CHARGEBACK',
  EXPIRED: 'EXPIRED',
  REQUIRES_REVIEW: 'REQUIRES_REVIEW',
} as const;
export type OrderStatus = (typeof OrderStatus)[keyof typeof OrderStatus];
