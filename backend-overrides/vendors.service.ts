import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
@Injectable()
export class VendorsService {
  constructor(private readonly prisma: PrismaService) {}
  async apply(userId: string, dto: {name:string;type:string;cityId:string;description?:string;address?:string}) {
    return this.prisma.$transaction(async tx => {
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user || user.role !== 'CUSTOMER') throw new BadRequestException('الحساب غير مؤهل لتقديم طلب بائع');
      const city = await tx.city.findFirst({ where: { id: dto.cityId, isActive: true }, select: { id: true } });
      if (!city) throw new NotFoundException('المدينة غير متاحة');
      if (await tx.vendor.findUnique({ where: { userId } })) throw new BadRequestException('يوجد طلب بائع لهذا الحساب');
      if (await tx.driver.findUnique({ where: { userId } })) throw new BadRequestException('لديك طلب سائق قائم بالفعل');
      const vendor = await tx.vendor.create({ data: { userId, type: dto.type, status: 'PENDING',
        translations: { create: { locale: 'ar', name: dto.name, description: dto.description } },
        cities: { create: { cityId: dto.cityId } },
        location: { create: { cityId: dto.cityId, address: dto.address } } } });
      return { id: vendor.id, status: vendor.status, message: 'تم استلام طلبك وسيتم مراجعته قبل تفعيل المتجر' };
    });
  }
  mine(userId: string) { return this.prisma.vendor.findUnique({ where: { userId }, select: { id: true, type: true, status: true, translations: { where: { locale: 'ar' }, take: 1 }, location: { select: { address: true, cityId: true } } } }); }
  list(cityId?: string, locale = 'ar') {
    return this.prisma.vendor.findMany({ where: { status: 'APPROVED', ...(cityId ? { cities: { some: { cityId } } } : {}) },
      orderBy: [{ ratingAvg: 'desc' }, { createdAt: 'desc' }],
      select: { id: true, type: true, ratingAvg: true, translations: { where: { locale: locale as any }, take: 1 }, location: { select: { address: true, cityId: true } }, _count: { select: { products: true } } } });
  }
  async get(id: string, locale = 'ar') {
    const vendor = await this.prisma.vendor.findFirst({ where: { id, status: 'APPROVED' },
      select: { id: true, type: true, ratingAvg: true, translations: { where: { locale: locale as any }, take: 1 }, location: { select: { address: true, cityId: true } }, cities: { select: { city: { select: { id: true, code: true, names: true } } } } } });
    if (!vendor) throw new NotFoundException('المتجر غير موجود');
    return vendor;
  }
}
