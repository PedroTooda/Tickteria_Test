const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();
const EVENT_ID = 'evt-show-28';

const SECTORS = [
  { id: 'sec-pista', name: 'Pista', capacity: 6000, priceCents: 12000 },
  { id: 'sec-camarote', name: 'Camarote', capacity: 1500, priceCents: 24000 },
  { id: 'sec-vip', name: 'VIP', capacity: 500, priceCents: 48000 },
  // Setor minúsculo para o cenário de corrida de capacidade (3 vagas, 10 compradores)
  { id: 'sec-teste', name: 'Setor de teste', capacity: 3, priceCents: 1000 },
];

async function main() {
  await prisma.event.upsert({
    where: { id: EVENT_ID },
    update: {},
    create: { id: EVENT_ID, name: 'Show do dia 28', startsAt: new Date('2026-09-28T22:00:00Z') },
  });
  for (const s of SECTORS) {
    await prisma.sector.upsert({
      where: { id: s.id },
      update: {}, // nunca zera "allocated" em re-execuções
      create: { ...s, eventId: EVENT_ID },
    });
  }
  console.log('seed ok: 1 evento e ' + SECTORS.length + ' setores');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
