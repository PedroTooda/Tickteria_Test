import { Module } from '@nestjs/common';
import { InfraModule } from './shared/infra.module';
import { HealthModule } from './modules/health/health.module';
import { OrdersModule } from './modules/orders/orders.module';
import { SupportModule } from './modules/support/support.module';
import { TicketsModule } from './modules/tickets/tickets.module';
import { WebhooksModule } from './modules/webhooks/webhooks.module';

@Module({
  imports: [
    InfraModule,
    HealthModule,
    OrdersModule,
    WebhooksModule,
    TicketsModule,
    SupportModule,
  ],
})
export class AppModule {}
