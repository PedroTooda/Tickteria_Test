import { UseCase } from '../../../shared/contracts/use-case.contract';

// TODO: definir o contrato de entrada e saída desta operação
export type ConfirmOrderInput = Record<string, never>;
export type ConfirmOrderOutput = void;

export class ConfirmOrderUseCase implements UseCase<ConfirmOrderInput, ConfirmOrderOutput> {
  // Dependências entram pelo construtor e são SEMPRE contratos (interfaces).
  async execute(_input: ConfirmOrderInput): Promise<ConfirmOrderOutput> {
    throw new Error('ConfirmOrderUseCase não implementado');
  }
}
