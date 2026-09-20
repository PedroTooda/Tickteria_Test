import { OrderStatus } from '../types/order-status.type';

export interface OrderItem {
  sectorId: string;
  quantity: number;
  unitPriceCents: number;
}

export interface Order {
  id: string;
  reference: string; // ex.: TKT-000412
  buyerEmail: string;
  status: OrderStatus;
  totalCents: number;
  items: OrderItem[];
  expiresAt: Date;
}
