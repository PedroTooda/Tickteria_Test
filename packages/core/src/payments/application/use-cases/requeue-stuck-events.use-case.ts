import { UseCase } from '../../../shared/contracts/use-case.contract';

// TODO: definir o contrato de entrada e saída desta operação
export type RequeueStuckEventsInput = Record<string, never>;
export type RequeueStuckEventsOutput = void;

export class RequeueStuckEventsUseCase implements UseCase<RequeueStuckEventsInput, RequeueStuckEventsOutput> {
  // Dependências entram pelo construtor e são SEMPRE contratos (interfaces).
  async execute(_input: RequeueStuckEventsInput): Promise<RequeueStuckEventsOutput> {
    throw new Error('RequeueStuckEventsUseCase não implementado');
  }
}
