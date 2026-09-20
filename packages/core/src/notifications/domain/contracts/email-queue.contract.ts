export interface EmailQueue {
  enqueue(deliveryId: string): Promise<void>;
}
