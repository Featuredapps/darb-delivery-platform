import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { IsArray, IsInt, IsOptional, IsEnum, IsString, IsUUID, Max, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { OrderStatus, UserRole } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { OrdersService } from './orders.service';
class OrderLineDto {
  @IsUUID() productId!: string;
  @Type(() => Number) @IsInt() @Min(1) @Max(50) quantity!: number;
}
class CreateOrderDto {
  @IsUUID() cityId!: string;
  @IsUUID() addressId!: string;
  @IsUUID() vendorId!: string;
  @IsArray() @ValidateNested({ each: true }) @Type(() => OrderLineDto) items!: OrderLineDto[];
  @IsOptional() @IsString() notes?: string;
}
class UpdateStatusDto { @IsEnum(OrderStatus) status!: OrderStatus; }
@Controller('orders') @UseGuards(JwtAuthGuard, RolesGuard)
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}
  @Post() @Roles(UserRole.CUSTOMER)
  create(@CurrentUser() user: {id:string}, @Body() dto: CreateOrderDto) { return this.orders.create(user.id, dto); }
  @Get('mine') @Roles(UserRole.CUSTOMER)
  mine(@CurrentUser() user: {id:string}) { return this.orders.mine(user.id); }
  @Get('vendor') @Roles(UserRole.VENDOR)
  vendorOrders(@CurrentUser() user: {id:string}) { return this.orders.vendorOrders(user.id); }
  @Get('driver/available') @Roles(UserRole.DRIVER)
  available(@CurrentUser() user: {id:string}) { return this.orders.availableForDriver(user.id); }
  @Get('driver/mine') @Roles(UserRole.DRIVER)
  driverMine(@CurrentUser() user: {id:string}) { return this.orders.driverMine(user.id); }
  @Post(':id/claim') @Roles(UserRole.DRIVER)
  claim(@CurrentUser() user: {id:string}, @Param('id') id: string) { return this.orders.claim(user.id, id); }
  @Patch(':id/status') @Roles(UserRole.VENDOR, UserRole.DRIVER)
  status(@CurrentUser() user: {id:string;role:UserRole}, @Param('id') id:string, @Body() dto:UpdateStatusDto) {
    return this.orders.updateStatus(user.id, user.role, id, dto.status);
  }
}
