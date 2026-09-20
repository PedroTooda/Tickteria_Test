import { EmailDelivery } from '../entities/email-delivery.entity';

export interface EmailDeliveryRepository {
  create(delivery: EmailDelivery): Promise<void>;
  findFailed(): Promise<EmailDelivery[]>;
  /** Transição atômica FAILED -> PENDING. false se outro já a fez (duplo clique). */
  tryRequeue(id: string): Promise<boolean>;
  markSent(id: string, at: Date): Promise<void>;
  markFailed(id: string, error: string): Promise<void>;
}
