import { PaymentEventType } from '../types/payment-event-type.type';
import { PaymentStatus } from '../types/payment-status.type';

const ABSORBING: PaymentStatus[] = [PaymentStatus.REFUNDED, PaymentStatus.CHARGEBACK];

export class PaymentStateMachine {
  next(current: PaymentStatus, event: PaymentEventType): PaymentStatus {
    if (ABSORBING.includes(current)) return current; // estado final: nada o desfaz
    switch (event) {
      case PaymentEventType.REFUNDED:
        return PaymentStatus.REFUNDED;
      case PaymentEventType.CHARGEBACK:
        return PaymentStatus.CHARGEBACK;
      case PaymentEventType.APPROVED:
        return current === PaymentStatus.PENDING ? PaymentStatus.APPROVED : current;
      case PaymentEventType.REFUSED:
        return current === PaymentStatus.PENDING ? PaymentStatus.REFUSED : current;
    }
  }
}
