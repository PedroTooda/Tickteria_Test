import { UseCase } from '../../../shared/contracts/use-case.contract';
import { UnitOfWork } from '../../../shared/contracts/unit-of-work.contract';
import { Clock } from '../../../shared/contracts/clock.contract';
import { IdGenerator } from '../../../shared/contracts/id-generator.contract';
import { OrderRepository } from '../../domain/contracts/order.repository.contract';
import { SectorCatalogRepository } from '../../domain/contracts/sector-catalog.repository.contract';
import { SectorInventoryRepository } from '../../../ticketing/domain/contracts/sector-inventory.repository.contract';
import { Order, OrderItem } from '../../domain/entities/order.entity';
import { OrderStatus } from '../../domain/types/order-status.type';
import { EmptyOrderError } from '../../../ordering/domain/errors/empty-order.error';
import { SectorNotFoundError } from '../../domain/errors/sector-not-found.error';
import { SectorSoldOutError } from '../../domain/errors/sector-sold-out.error';
import { buildOrderReference, ORDER_TTL_MINUTES } from '../../domain/services/order-reference.generator';

export interface CreateOrderInput {
  buyerEmail: string;
  items: { sectorId: string; quantity: number }[];
}

export interface CreateOrderOutput {
  orderId: string;
  reference: string;
  totalCents: number;
  expiresAt: Date;
}

export class CreateOrderUseCase implements UseCase<CreateOrderInput, CreateOrderOutput> {
  constructor(
    private readonly uow: UnitOfWork,
    private readonly orders: OrderRepository,
    private readonly catalog: SectorCatalogRepository,
    private readonly inventory: SectorInventoryRepository,
    private readonly ids: IdGenerator,
    private readonly clock: Clock,
  ) {}

  async execute(input: CreateOrderInput): Promise<CreateOrderOutput> {
    const items = input.items.filter((i) => i.quantity > 0);
    if (items.length === 0) throw new EmptyOrderError();

    // Tudo numa transação: se um setor esgotar, as reservas anteriores voltam atrás.
    return this.uow.run(async () => {
      const orderItems: OrderItem[] = [];

      for (const item of items) {
        const sector = await this.catalog.findById(item.sectorId);
        if (!sector) throw new SectorNotFoundError(item.sectorId);

        // Reserva ANTES de cobrar: melhor negar a venda do que vender o que não existe.
        const allocated = await this.inventory.tryAllocate(item.sectorId, item.quantity);
        if (!allocated) throw new SectorSoldOutError(item.sectorId, item.quantity);

        orderItems.push({
          sectorId: sector.id,
          quantity: item.quantity,
          unitPriceCents: sector.priceCents,
        });
      }

      const now = this.clock.now();
      const id = this.ids.uuid();
      const order: Order = {
        id,
        reference: buildOrderReference(id),
        buyerEmail: input.buyerEmail,
        status: OrderStatus.PENDING_PAYMENT,
        totalCents: orderItems.reduce((sum, i) => sum + i.quantity * i.unitPriceCents, 0),
        items: orderItems,
        expiresAt: new Date(now.getTime() + ORDER_TTL_MINUTES * 60_000),
      };

      await this.orders.create(order);

      return {
        orderId: order.id,
        reference: order.reference,
        totalCents: order.totalCents,
        expiresAt: order.expiresAt,
      };
    });
  }
}