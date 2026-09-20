import { DomainError } from '../../../shared/errors/domain.error';

export class InvalidSignatureError extends DomainError {
  readonly code = 'INVALID_SIGNATURE';
  constructor() {
    super('Assinatura do webhook inválida');
  }
}
