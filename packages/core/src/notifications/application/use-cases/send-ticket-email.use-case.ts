import { UseCase } from '../../../shared/contracts/use-case.contract';

// TODO: definir o contrato de entrada e saída desta operação
export type SendTicketEmailInput = Record<string, never>;
export type SendTicketEmailOutput = void;

export class SendTicketEmailUseCase implements UseCase<SendTicketEmailInput, SendTicketEmailOutput> {
  // Dependências entram pelo construtor e são SEMPRE contratos (interfaces).
  async execute(_input: SendTicketEmailInput): Promise<SendTicketEmailOutput> {
    throw new Error('SendTicketEmailUseCase não implementado');
  }
}
