export interface CreateOrderDto {
  buyerEmail: string;
  items: { sectorId: string; quantity: number }[];
}
