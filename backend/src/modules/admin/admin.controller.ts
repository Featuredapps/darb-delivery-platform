import { Body, Controller, Get, Param, Patch, UseGuards } from '@nestjs/common';
import { DriverStatus, VendorStatus, UserRole } from '@prisma/client';
import { IsEnum } from 'class-validator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { PrismaService } from '../../prisma/prisma.service';

class VendorStatusDto { @IsEnum(VendorStatus) status!: VendorStatus; }
class DriverStatusDto { @IsEnum(DriverStatus) status!: DriverStatus; }

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class AdminController {
  constructor(private readonly prisma: PrismaService) {}

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
