import { Ticket } from '../entities/ticket.entity';

export interface TicketRepository {
  saveMany(tickets: Ticket[]): Promise<void>;
  findByOrderId(orderId: string): Promise<Ticket[]>;
  findByCode(code: string): Promise<Ticket | null>;
  voidByOrderId(orderId: string, at: Date): Promise<void>;
}
