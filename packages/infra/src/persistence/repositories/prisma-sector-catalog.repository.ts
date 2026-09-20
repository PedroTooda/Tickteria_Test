import { SectorCatalogRepository, SectorSnapshot } from '@tickteira/core/src/ordering/domain/contracts/sector-catalog.repository.contract';
import { PrismaContext } from '../prisma.context';

export class PrismaSectorCatalogRepository implements SectorCatalogRepository {
  constructor(private readonly ctx: PrismaContext) {}

  async findById(sectorId: string): Promise<SectorSnapshot | null> {
    const row = await this.ctx.client.sector.findUnique({ where: { id: sectorId } });
    return row ? { id: row.id, name: row.name, priceCents: row.priceCents } : null;
  }
}