import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { DriverStatus, VendorStatus, UserRole } from '@prisma/client';
import { IsBoolean, IsEnum, IsNumber, IsOptional, IsString, IsUUID, MaxLength, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { PrismaService } from '../../prisma/prisma.service';

class VendorStatusDto { @IsEnum(VendorStatus) status!: VendorStatus; }
class DriverStatusDto { @IsEnum(DriverStatus) status!: DriverStatus; }
class CityStatusDto { @IsBoolean() isActive!: boolean; }
class DeliveryZoneDto {
  @IsUUID() cityId!: string;
  @IsString() @MaxLength(80) name!: string;
  @Type(() => Number) @IsNumber() @Min(0) feeBase!: number;
  @Type(() => Number) @IsNumber() @Min(0) feePerKm!: number;
}
class UpdateDeliveryZoneDto {
  @IsOptional() @IsString() @MaxLength(80) name?: string;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) feeBase?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) feePerKm?: number;
}

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class AdminController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('overview')
  async overview() {
    const [customers, vendors, pendingVendors, drivers, pendingDrivers, orders, activeCities] = await Promise.all([
      this.prisma.user.count({ where: { role: UserRole.CUSTOMER } }),
      this.prisma.vendor.count(),
      this.prisma.vendor.count({ where: { status: VendorStatus.PENDING } }),
      this.prisma.driver.count(),
      this.prisma.driver.count({ where: { status: DriverStatus.PENDING } }),
      this.prisma.order.count(),
      this.prisma.city.count({ where: { isActive: true } }),
    ]);
    return { customers, vendors, pendingVendors, drivers, pendingDrivers, orders, activeCities };
  }

  @Get('cities')
  cities() {
    return this.prisma.city.findMany({
      orderBy: { code: 'asc' },
      select: { id: true, code: true, isActive: true, defaultCurrency: true, supportedLocales: true, names: true, _count: { select: { vendors: true, drivers: true, orders: true } } },
    });
  }

  @Patch('cities/:id/status')
  setCityStatus(@Param('id') id: string, @Body() dto: CityStatusDto) {
    return this.prisma.city.update({ where: { id }, data: { isActive: dto.isActive } });
  }

  @Get('delivery-zones')
  deliveryZones() {
    return this.prisma.deliveryZone.findMany({ orderBy: [{ cityId: 'asc' }, { name: 'asc' }], include: { city: { select: { id: true, code: true, names: true } } } });
  }

  @Post('delivery-zones')
  createDeliveryZone(@Body() dto: DeliveryZoneDto) {
    return this.prisma.deliveryZone.create({ data: dto });
  }

  @Patch('delivery-zones/:id')
  updateDeliveryZone(@Param('id') id: string, @Body() dto: UpdateDeliveryZoneDto) {
    return this.prisma.deliveryZone.update({ where: { id }, data: dto });
  }

  @Get('vendors/pending')
  pendingVendors() {
    return this.prisma.vendor.findMany({
      where: { status: VendorStatus.PENDING },
      orderBy: { createdAt: 'asc' },
      include: { user: { select: { id: true, name: true, phone: true } }, translations: true, cities: { include: { city: { select: { id: true, code: true, names: true } } } }, location: true },
    });
  }

  @Patch('vendors/:id/status')
  async setVendorStatus(@Param('id') id: string, @Body() dto: VendorStatusDto) {
    return this.prisma.vendor.update({ where: { id }, data: { status: dto.status } });
  }

  @Get('drivers/pending')
  pendingDrivers() {
    return this.prisma.driver.findMany({
      where: { status: DriverStatus.PENDING },
      orderBy: { createdAt: 'asc' },
      include: { user: { select: { id: true, name: true, phone: true } }, city: { select: { id: true, code: true, names: true } } },
    });
  }

  @Patch('drivers/:id/status')
  async setDriverStatus(@Param('id') id: string, @Body() dto: DriverStatusDto) {
    return this.prisma.driver.update({
      where: { id },
      data: { status: dto.status, ...(dto.status === DriverStatus.APPROVED ? {} : { isOnline: false }) },
    });
  }
}
