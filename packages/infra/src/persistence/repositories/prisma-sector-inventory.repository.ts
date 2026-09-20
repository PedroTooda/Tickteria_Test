import { SectorInventoryRepository } from '@tickteira/core';
import { PrismaContext } from '../prisma.context';

export class PrismaSectorInventoryRepository implements SectorInventoryRepository {
  constructor(private readonly ctx: PrismaContext) {}

  /**
   * O WHERE é a trava: o Postgres serializa UPDATEs concorrentes na MESMA linha,
   * então dois compradores nunca leem "allocated" desatualizado. 0 linhas = esgotado.
   */
  async tryAllocate(sectorId: string, quantity: number): Promise<boolean> {
    const affected = await this.ctx.client.$executeRaw`
      UPDATE sectors
         SET allocated = allocated + ${quantity}
       WHERE id = ${sectorId}
         AND allocated + ${quantity} <= capacity`;
    return affected === 1;
  }

  /** Devolve capacidade (usado ao estornar/expirar). */
  async release(sectorId: string, quantity: number): Promise<void> {
    await this.ctx.client.$executeRaw`
      UPDATE sectors
         SET allocated = GREATEST(allocated - ${quantity}, 0)
       WHERE id = ${sectorId}`;
  }
}