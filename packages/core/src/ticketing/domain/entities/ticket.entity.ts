import { TicketStatus } from '../types/ticket-status.type';

export interface Ticket {
  id: string;
  orderId: string;
  sectorId: string;
  code: string; // conteúdo do QR
  status: TicketStatus;
  issuedAt: Date;
  voidedAt: Date | null;
}
