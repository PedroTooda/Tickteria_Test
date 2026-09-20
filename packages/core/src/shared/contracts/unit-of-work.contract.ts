/** Executa o trabalho numa única transação atômica. */
export interface UnitOfWork {
  run<T>(work: () => Promise<T>): Promise<T>;
}
