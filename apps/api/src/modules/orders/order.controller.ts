import { Body, Controller, HttpCode, Inject, Post } from '@nestjs/common';
import { CreateOrderUseCase } from '@tickteira/core';
import { TOKENS } from '../../shared/di-tokens';
import { parseCreateOrder } from './dtos/create-order.request';

@Controller('orders')
export class OrdersController {
  constructor(@Inject(TOKENS.CreateOrderUseCase) private readonly createOrder: CreateOrderUseCase) {}

  @Post()
  @HttpCode(201)
  async create(@Body() body: unknown) {
    return this.createOrder.execute(parseCreateOrder(body));
  }
}