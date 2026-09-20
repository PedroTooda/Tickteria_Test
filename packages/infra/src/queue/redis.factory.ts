import { Redis } from 'ioredis';

export function createRedis(url: string): Redis {
  return new Redis(url);
}

/** Opções de conexão para BullMQ (maxRetriesPerRequest null é exigido pelos Workers). */
export function redisConnectionFromUrl(url: string) {
  const parsed = new URL(url);
  return {
    host: parsed.hostname,
    port: Number(parsed.port || 6379),
    maxRetriesPerRequest: null as null,
  };
}
