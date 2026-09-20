import { Order } from '../entities/order.entity';

export interface OrderRepository {
  create(order: Order): Promise<void>;
  findByReferenceForUpdate(reference: string): Promise<Order | null>;
  save(order: Order): Promise<void>;
}
