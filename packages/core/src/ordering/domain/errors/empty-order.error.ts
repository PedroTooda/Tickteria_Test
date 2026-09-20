import { DomainError } from '../../../shared/errors/domain.error';

export class EmptyOrderError extends DomainError {
  readonly code = 'EMPTY_ORDER';
  constructor() {
    super('O pedido precisa de ao menos um item com quantidade positiva');
  }
}