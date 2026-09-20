import { UseCase } from '../../../shared/contracts/use-case.contract';

// TODO: definir o contrato de entrada e saída desta operação
export type ProcessPaymentEventInput = Record<string, never>;
export type ProcessPaymentEventOutput = void;

export class ProcessPaymentEventUseCase implements UseCase<ProcessPaymentEventInput, ProcessPaymentEventOutput> {
  // Dependências entram pelo construtor e são SEMPRE contratos (interfaces).
  async execute(_input: ProcessPaymentEventInput): Promise<ProcessPaymentEventOutput> {
    throw new Error('ProcessPaymentEventUseCase não implementado');
  }
}
