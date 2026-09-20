// Tokens de injeção: ligam contratos (interfaces) às implementações do infra.
export const TOKENS = {
  Prisma: Symbol('Prisma'),
  Redis: Symbol('Redis'),
} as const;
