import { BadRequestException } from '@nestjs/common';
import type { CreateOrderInput } from '@tickteira/core';

const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

interface RawBody {
  buyerEmail?: unknown;
  items?: unknown;
}

/** Validação de borda: formato. Regra de negócio fica no use case. */
export function parseCreateOrder(body: unknown): CreateOrderInput {
  const b = (body ?? {}) as RawBody;

  if (typeof b.buyerEmail !== 'string' || !EMAIL.test(b.buyerEmail)) {
    throw new BadRequestException('buyerEmail inválido');
  }
  const buyerEmail: string = b.buyerEmail;

  const rawItems: unknown[] = Array.isArray(b.items) ? b.items : [];
  if (rawItems.length === 0) {
    throw new BadRequestException('items é obrigatório');
  }

  const items = rawItems.map((raw): { sectorId: string; quantity: number } => {
    const item = raw as { sectorId?: unknown; quantity?: unknown };
    if (typeof item.sectorId !== 'string' || !Number.isInteger(item.quantity)) {
      throw new BadRequestException('item inválido: { sectorId: string, quantity: int }');
    }
    return { sectorId: item.sectorId, quantity: item.quantity as number };
  });

  return { buyerEmail, items };
}