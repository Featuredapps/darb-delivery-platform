import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { DriverStatus, VendorStatus, UserRole } from '@prisma/client';
import { IsEnum, IsNumber, IsOptional, IsString, IsUUID, MaxLength, Min } from 'class-validator';
import { BadRequestException } from '@nestjs/common';
import { Type } from 'class-transformer';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { PrismaService } from '../../prisma/prisma.service';
class VendorStatusDto { @IsEnum(VendorStatus) status!: VendorStatus; }
class DriverStatusDto { @IsEnum(DriverStatus) status!: DriverStatus; }

class CreateDeliveryZoneDto {
  @IsUUID() cityId!: string;
  @IsString() @MaxLength(80) name!: string;
  @Type(() => Number) @IsNumber({ maxDecimalPlaces: 2 }) @Min(0) feeBase!: number;
  @Type(() => Number) @IsNumber({ maxDecimalPlaces: 2 }) @Min(0) feePerKm!: number;
}
class UpdateDeliveryZoneDto {
  @IsOptional() @IsString() @MaxLength(80) name?: string;
  @IsOptional() @Type(() => Number) @IsNumber({ maxDecimalPlaces: 2 }) @Min(0) feeBase?: number;
  @IsOptional() @Type(() => Number) @IsNumber({ maxDecimalPlaces: 2 }) @Min(0) feePerKm?: number;
}

@Controller('admin') @UseGuards(JwtAuthGuard, RolesGuard) @Roles(UserRole.ADMIN)
export class AdminController {
  constructor(private readonly prisma: PrismaService) {}
  @Get('delivery-zones') deliveryZones() {
    return this.prisma.deliveryZone.findMany({ orderBy: [{ cityId: 'asc' }, { name: 'asc' }], include: { city: { select: { id: true, code: true, names: true } } } });
  }
  @Post('delivery-zones') async createDeliveryZone(@Body() dto: CreateDeliveryZoneDto) {
    const city = await this.prisma.city.findFirst({ where: { id: dto.cityId, isActive: true }, select: { id: true } });
    if (!city) throw new BadRequestException('المدينة غير متاحة');
    return this.prisma.deliveryZone.create({ data: dto });
  }
  @Patch('delivery-zones/:id') updateDeliveryZone(@Param('id') id: string, @Body() dto: UpdateDeliveryZoneDto) {
    return this.prisma.deliveryZone.update({ where: { id }, data: dto });
  }
  @Get('vendors/pending') pendingVendors() {
    return this.prisma.vendor.findMany({ where: { status: VendorStatus.PENDING }, orderBy: { createdAt: 'asc' },
      include: { user: { select: { id: true, name: true, phone: true, email: true } }, translations: true, cities: { include: { city: { select: { id: true, code: true, names: true } } } }, location: true } });
  }
  @Patch('vendors/:id/status') async setVendorStatus(@Param('id') id: string, @Body() dto: VendorStatusDto) {
    return this.prisma.$transaction(async tx => {
      const vendor = await tx.vendor.update({ where: { id }, data: { status: dto.status } });
      if (dto.status === VendorStatus.APPROVED) await tx.user.update({ where: { id: vendor.userId }, data: { role: UserRole.VENDOR } });
      else await tx.user.updateMany({ where: { id: vendor.userId, role: UserRole.VENDOR }, data: { role: UserRole.CUSTOMER } });
      return vendor;
    });
  }
  @Get('drivers/pending') pendingDrivers() {
    return this.prisma.driver.findMany({ where: { status: DriverStatus.PENDING }, orderBy: { createdAt: 'asc' },
      include: { user: { select: { id: true, name: true, phone: true, email: true } }, city: { select: { id: true, code: true, names: true } } } });
  }
  @Patch('drivers/:id/status') async setDriverStatus(@Param('id') id: string, @Body() dto: DriverStatusDto) {
    return this.prisma.$transaction(async tx => {
      const driver = await tx.driver.update({ where: { id }, data: { status: dto.status, ...(dto.status === DriverStatus.APPROVED ? {} : { isOnline: false }) } });
      if (dto.status === DriverStatus.APPROVED) await tx.user.update({ where: { id: driver.userId }, data: { role: UserRole.DRIVER } });
      else await tx.user.updateMany({ where: { id: driver.userId, role: UserRole.DRIVER }, data: { role: UserRole.CUSTOMER } });
      return driver;
    });
  }
}
