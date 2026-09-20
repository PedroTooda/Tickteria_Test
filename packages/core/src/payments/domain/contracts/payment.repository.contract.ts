import { Payment } from '../entities/payment.entity';

export interface PaymentRepository {
  /** Busca com lock pessimista (SELECT ... FOR UPDATE). Só dentro de UnitOfWork. */
  findByProviderIdForUpdate(providerPaymentId: string): Promise<Payment | null>;
  save(payment: Payment): Promise<void>;
}
