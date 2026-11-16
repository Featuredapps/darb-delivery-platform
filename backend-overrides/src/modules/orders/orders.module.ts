import { Module } from '@nestjs/common';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { OrderTrackingController } from './tracking.controller';

@Module({
  controllers: [OrdersController, OrderTrackingController],
  providers: [OrdersService],
})
export class OrdersModule {}
