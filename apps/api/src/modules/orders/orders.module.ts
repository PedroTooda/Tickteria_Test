import { Module } from '@nestjs/common';
import { CreateOrderUseCase } from '@tickteira/core';
import { TOKENS } from '../../shared/di-tokens';
import { OrdersController } from './order.controller';

@Module({
  controllers: [OrdersController],
  providers: [
    {
      provide: TOKENS.CreateOrderUseCase,
      useFactory: (uow, orders, catalog, inventory, ids, clock) =>
        new CreateOrderUseCase(uow, orders, catalog, inventory, ids, clock),
      inject: [
        TOKENS.UnitOfWork,
        TOKENS.OrderRepository,
        TOKENS.SectorCatalogRepository,
        TOKENS.SectorInventoryRepository,
        TOKENS.IdGenerator,
        TOKENS.Clock,
      ],
    },
  ],
})
export class OrdersModule {}