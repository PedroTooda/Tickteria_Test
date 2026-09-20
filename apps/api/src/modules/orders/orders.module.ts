import { Module } from '@nestjs/common';

// Controllers só traduzem HTTP -> UseCase.execute(). Nenhuma regra de negócio aqui.
@Module({ controllers: [], providers: [] })
export class OrdersModule {}
