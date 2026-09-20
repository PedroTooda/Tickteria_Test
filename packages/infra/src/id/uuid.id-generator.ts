import { randomUUID } from 'node:crypto';
import { IdGenerator } from '@tickteira/core/src/shared/contracts/id-generator.contract';

export class UuidIdGenerator implements IdGenerator {
  uuid(): string {
    return randomUUID();
  }
}