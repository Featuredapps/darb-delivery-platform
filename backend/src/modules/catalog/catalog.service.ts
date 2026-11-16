import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
@Injectable()
export class CatalogService {
  constructor(private readonly prisma: PrismaService) {}
  async list(vendorId: string, locale = 'ar') {
    const vendor = await this.prisma.vendor.findFirst({ where: { id: vendorId, status: 'APPROVED' }, select: { id: true } });
    if (!vendor) throw new NotFoundException('المتجر غير متاح');
    return this.prisma.product.findMany({ where: { vendorId, isAvailable: true }, orderBy: { createdAt: 'desc' },
      select: { id: true, basePrice: true, currency: true, imageUrl: true, variants: { where: { isAvailable: true } },
        translations: { where: { locale: locale as any }, take: 1 } } });
  }
  async create(userId: string, dto: {name:string;description?:string;price:number;currency?:string;imageUrl?:string;stockQty?:number}) {
    const vendor = await this.prisma.vendor.findUnique({ where: { userId } });
    if (!vendor || vendor.status !== 'APPROVED') throw new ForbiddenException('حساب البائع غير معتمد');
    return this.prisma.product.create({ data: { vendorId: vendor.id, basePrice: dto.price, currency: dto.currency ?? 'SYP',
      imageUrl: dto.imageUrl, stockQty: dto.stockQty, translations: { create: { locale: 'ar', name: dto.name, description: dto.description } } },
      include: { translations: true } });
  }
}
