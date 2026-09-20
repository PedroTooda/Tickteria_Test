export interface PaymentEventQueue {
  /** Deduplica por eventId (jobId). */
  enqueue(eventId: string): Promise<void>;
}
