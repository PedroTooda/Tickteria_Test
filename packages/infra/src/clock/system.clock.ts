import { Clock } from '@tickteira/core';

export class SystemClock implements Clock {
  now(): Date {
    return new Date();
  }
}
