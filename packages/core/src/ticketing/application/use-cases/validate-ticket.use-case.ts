import { UseCase } from '../../../shared/contracts/use-case.contract';

// TODO: definir o contrato de entrada e saída desta operação
export type ValidateTicketInput = Record<string, never>;
export type ValidateTicketOutput = void;

export class ValidateTicketUseCase implements UseCase<ValidateTicketInput, ValidateTicketOutput> {
  // Dependências entram pelo construtor e são SEMPRE contratos (interfaces).
  async execute(_input: ValidateTicketInput): Promise<ValidateTicketOutput> {
    throw new Error('ValidateTicketUseCase não implementado');
  }
}
