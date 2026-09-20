import { AsyncLocalStorage } from 'node:async_hooks';
import { Prisma, PrismaClient } from '@prisma/client';

export type PrismaTx = Prisma.TransactionClient;

/** Guarda o client "corrente": o da transação, se houver; senão o global. */
export class PrismaContext {
  private readonly als = new AsyncLocalStorage<PrismaTx>();

  constructor(private readonly root: PrismaClient) {}

  get client(): PrismaTx {
    return this.als.getStore() ?? this.root;
  }

  get inTransaction(): boolean {
    return this.als.getStore() !== undefined;
  }

  runInTransaction<T>(tx: PrismaTx, work: () => Promise<T>): Promise<T> {
    return this.als.run(tx, work);
  }
}