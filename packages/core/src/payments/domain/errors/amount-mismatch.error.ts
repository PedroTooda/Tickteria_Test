import { DomainError } from '../../../shared/errors/domain.error';

export class AmountMismatchError extends DomainError {
  readonly code = 'AMOUNT_MISMATCH';
  constructor(expected: number, received: number) {
    super(`Valor esperado ${expected}, recebido ${received}`);
  }
}
