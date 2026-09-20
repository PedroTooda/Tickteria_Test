import { UseCase } from '../../../shared/contracts/use-case.contract';

// TODO: definir o contrato de entrada e saída desta operação
export type IssueTicketsInput = Record<string, never>;
export type IssueTicketsOutput = void;

export class IssueTicketsUseCase implements UseCase<IssueTicketsInput, IssueTicketsOutput> {
  // Dependências entram pelo construtor e são SEMPRE contratos (interfaces).
  async execute(_input: IssueTicketsInput): Promise<IssueTicketsOutput> {
    throw new Error('IssueTicketsUseCase não implementado');
  }
}
