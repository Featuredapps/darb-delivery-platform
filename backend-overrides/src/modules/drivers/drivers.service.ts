import { Injectable, BadRequestException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class DriversService {
  constructor(private readonly prisma: PrismaService) {}

  async me(userId: string) {
    const driver = await this.prisma.driver.findUnique({
      where: { userId },
      select: { id: true, status: true, isOnline: true, cityId: true, vehicleType: true },
    });
    if (!driver) throw new BadRequestException('لا يوجد ملف سائق لهذا الحساب');
    return driver;
  }

  async setOnline(userId: string, isOnline: boolean) {
    const driver = await this.prisma.driver.findUnique({ where: { userId } });
    if (!driver || driver.status !== 'APPROVED') {
      throw new BadRequestException('حساب السائق غير معتمد');
    }
    return this.prisma.driver.update({ where: { userId }, data: { isOnline } });
  }

  async updateLocation(userId: string, latitude: number, longitude: number) {
    const driver = await this.prisma.driver.findUnique({ where: { userId } });
    if (!driver || driver.status !== 'APPROVED' || !driver.isOnline) {
      throw new ForbiddenException('يجب أن يكون حساب السائق معتمداً ومتّصلاً');
    }
    await this.prisma.$executeRaw`
      INSERT INTO "DriverLocation" ("driverId", "point", "updatedAt")
      VALUES (${driver.id}, ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography, NOW())
      ON CONFLICT ("driverId") DO UPDATE
      SET "point" = EXCLUDED."point", "updatedAt" = NOW()
    `;
    return { updated: true, timestamp: new Date().toISOString() };
  }

  async apply(userId: string, dto: { cityId: string; vehicleType?: string }) {
    return this.prisma.$transaction(async tx => {
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user || user.role !== 'CUSTOMER') throw new BadRequestException('الحساب غير مؤهل لتقديم طلب سائق');
      const city = await tx.city.findFirst({ where: { id: dto.cityId, isActive: true }, select: { id: true } });
      if (!city) throw new BadRequestException('المدينة غير متاحة');
      if (await tx.driver.findUnique({ where: { userId } })) throw new BadRequestException('يوجد طلب سائق لهذا الحساب');
      const driver = await tx.driver.create({
        data: { userId, cityId: dto.cityId, vehicleType: dto.vehicleType, status: 'PENDING' },
      });
      await tx.user.update({ where: { id: userId }, data: { role: 'DRIVER' } });
      return { id: driver.id, status: driver.status, message: 'تم استلام طلبك وسيتم مراجعة الطلب قبل تفعيل الحساب' };
    });
  }
}
