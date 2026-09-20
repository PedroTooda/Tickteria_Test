/** TKT-A1B2C3D4 — derivado do uuid, testável e sem depender de infra. */
export function buildOrderReference(uuid: string): string {
  return `TKT-${uuid.replace(/-/g, '').slice(0, 8).toUpperCase()}`;
}

/** Janela de reserva: depois disso o pedido expira e a capacidade volta. */
export const ORDER_TTL_MINUTES = 15;