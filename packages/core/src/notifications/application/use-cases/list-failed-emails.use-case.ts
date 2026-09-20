import { UseCase } from '../../../shared/contracts/use-case.contract';

// TODO: definir o contrato de entrada e saída desta operação
export type ListFailedEmailsInput = Record<string, never>;
export type ListFailedEmailsOutput = void;

export class ListFailedEmailsUseCase implements UseCase<ListFailedEmailsInput, ListFailedEmailsOutput> {
  // Dependências entram pelo construtor e são SEMPRE contratos (interfaces).
  async execute(_input: ListFailedEmailsInput): Promise<ListFailedEmailsOutput> {
    throw new Error('ListFailedEmailsUseCase não implementado');
  }
}
