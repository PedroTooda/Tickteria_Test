import { UseCase } from '../../../shared/contracts/use-case.contract';

// TODO: definir o contrato de entrada e saída desta operação
export type VoidTicketsInput = Record<string, never>;
export type VoidTicketsOutput = void;

export class VoidTicketsUseCase implements UseCase<VoidTicketsInput, VoidTicketsOutput> {
  // Dependências entram pelo construtor e são SEMPRE contratos (interfaces).
  async execute(_input: VoidTicketsInput): Promise<VoidTicketsOutput> {
    throw new Error('VoidTicketsUseCase não implementado');
  }
}
