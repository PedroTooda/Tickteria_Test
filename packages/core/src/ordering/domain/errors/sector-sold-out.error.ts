import { DomainError } from '../../../shared/errors/domain.error';

export class SectorSoldOutError extends DomainError {
  readonly code = 'SECTOR_SOLD_OUT';
  constructor(sectorId: string, requested: number) {
    super(`Setor ${sectorId} não tem ${requested} lugares disponíveis`);
  }
}