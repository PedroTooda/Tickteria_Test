import { UseCase } from '../../../shared/contracts/use-case.contract';

// TODO: definir o contrato de entrada e saída desta operação
export type ResendEmailInput = Record<string, never>;
export type ResendEmailOutput = void;

export class ResendEmailUseCase implements UseCase<ResendEmailInput, ResendEmailOutput> {
  // Dependências entram pelo construtor e são SEMPRE contratos (interfaces).
  async execute(_input: ResendEmailInput): Promise<ResendEmailOutput> {
    throw new Error('ResendEmailUseCase não implementado');
  }
}
