export interface SectorSnapshot {
  id: string;
  name: string;
  priceCents: number;
}

/** Leitura de catálogo: preço vigente do setor no momento da compra. */
export interface SectorCatalogRepository {
  findById(sectorId: string): Promise<SectorSnapshot | null>;
}