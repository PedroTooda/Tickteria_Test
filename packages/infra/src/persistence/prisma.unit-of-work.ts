import { PrismaClient } from '@prisma/client';
import { UnitOfWork } from '@tickteira/core';
import { PrismaContext } from './prisma.context';

export class PrismaUnitOfWork implements UnitOfWork {
  constructor(
    private readonly ctx: PrismaContext,
    private readonly prisma: PrismaClient,
  ) {}

  run<T>(work: () => Promise<T>): Promise<T> {
    // Aninhado: reaproveita a transação externa em vez de abrir outra.
    if (this.ctx.inTransaction) return work();
    return this.prisma.$transaction((tx) => this.ctx.runInTransaction(tx, work), {
      timeout: 15_000,
    });
  }
}