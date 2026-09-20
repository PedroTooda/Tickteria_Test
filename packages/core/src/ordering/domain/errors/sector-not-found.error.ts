import { DomainError } from '../../../shared/errors/domain.error';

export class SectorNotFoundError extends DomainError {
  readonly code = 'SECTOR_NOT_FOUND';
  constructor(sectorId: string) {
    super(`Setor ${sectorId} não existe`);
  }
}