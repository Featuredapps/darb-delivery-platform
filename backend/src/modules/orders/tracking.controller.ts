import { Controller, Get, NotFoundException, Param, UseGuards } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { PrismaService } from '../../prisma/prisma.service';

@Controller('orders')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.CUSTOMER)
export class OrderTrackingController {
  constructor(private readonly prisma: PrismaService) {}

  @Get(':id/tracking')
  async tracking(@CurrentUser() user: { id: string }, @Param('id') id: string) {
    const order = await this.prisma.order.findFirst({
      where: { id, customerId: user.id },
      select: { id: true, status: true, driverId: true, updatedAt: true },
    });
    if (!order) throw new NotFoundException('الطلب غير موجود');
    if (!order.driverId || !['ASSIGNED', 'PICKED_UP'].includes(order.status)) {
      return { status: order.status, location: null };
    }
    const rows = await this.prisma.$queryRaw<Array<{
      latitude: number;
      longitude: number;
      updatedAt: Date;
    }>>`
      SELECT ST_Y("point"::geometry) AS latitude,
             ST_X("point"::geometry) AS longitude,
             "updatedAt"
      FROM "DriverLocation"
      WHERE "driverId" = ${order.driverId}
      LIMIT 1
    `;
    const location = rows[0] ?? null;
    return {
      status: order.status,
      location: location ? {
        latitude: Number(location.latitude),
        longitude: Number(location.longitude),
        updatedAt: location.updatedAt,
      } : null,
    };
  }
}
