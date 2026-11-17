import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
@Injectable()
export class OrderTrackingService {
  constructor(private readonly prisma: PrismaService) {}
  async driverLocation(userId: string, orderId: string) {
    const order = await this.prisma.order.findFirst({ where: { id: orderId, customerId: userId }, select: { driverId: true, status: true } });
    if (!order) throw new NotFoundException('الطلب غير موجود');
    if (!order.driverId || !['ASSIGNED', 'PICKED_UP'].includes(order.status)) return { available: false };
    const rows = await this.prisma.$queryRaw<Array<{latitude: number; longitude: number; updatedAt: Date}>>`SELECT ST_Y("point"::geometry) AS latitude, ST_X("point"::geometry) AS longitude, "updatedAt" FROM "DriverLocation" WHERE "driverId" = ${order.driverId} AND "point" IS NOT NULL`;
    if (!rows.length) return { available: false };
    return { available: true, ...rows[0] };
  }
}
