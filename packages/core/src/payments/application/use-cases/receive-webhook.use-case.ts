import { UseCase } from '../../../shared/contracts/use-case.contract';

// TODO: definir o contrato de entrada e saída desta operação
export type ReceiveWebhookInput = Record<string, never>;
export type ReceiveWebhookOutput = void;

export class ReceiveWebhookUseCase implements UseCase<ReceiveWebhookInput, ReceiveWebhookOutput> {
  // Dependências entram pelo construtor e são SEMPRE contratos (interfaces).
  async execute(_input: ReceiveWebhookInput): Promise<ReceiveWebhookOutput> {
    throw new Error('ReceiveWebhookUseCase não implementado');
  }
}
