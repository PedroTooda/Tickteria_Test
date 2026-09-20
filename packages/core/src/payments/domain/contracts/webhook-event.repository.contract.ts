import { WebhookEvent } from '../entities/webhook-event.entity';

export interface WebhookEventRepository {
  /** @returns true se inseriu; false se o event_id já existia (duplicado). */
  insertIfAbsent(event: WebhookEvent): Promise<boolean>;
  findStuck(olderThan: Date, limit: number): Promise<WebhookEvent[]>;
  markProcessed(eventId: string): Promise<void>;
  markFailed(eventId: string, reason: string): Promise<void>;
}
