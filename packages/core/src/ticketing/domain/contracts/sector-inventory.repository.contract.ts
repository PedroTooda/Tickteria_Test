export interface SectorInventoryRepository {
  /** Reserva atômica: UPDATE ... WHERE allocated + qty <= capacity. false = esgotado. */
  tryAllocate(sectorId: string, quantity: number): Promise<boolean>;

  release(sectorId: string, quantity: number): Promise<void>;
}