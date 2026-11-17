import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { OrderStatus, UserRole } from '@prisma/client';
import { randomBytes } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
@Injectable()
export class OrdersService {
  constructor(private readonly prisma: PrismaService) {}
  async create(customerId: string, dto: {cityId:string;addressId:string;vendorId:string;items:{productId:string;quantity:number}[];notes?:string}) {
    if (!dto.items?.length || dto.items.length > 30) throw new BadRequestException('قائمة المنتجات غير صالحة');
    const ids = [...new Set(dto.items.map(x => x.productId))];
    if (ids.length !== dto.items.length) throw new BadRequestException('لا تكرر المنتج في السلة');
    return this.prisma.$transaction(async tx => {
      const [address, city, vendor, deliveryZone] = await Promise.all([
        tx.address.findFirst({ where: { id: dto.addressId, userId: customerId }, select: { id: true } }),
        tx.city.findFirst({ where: { id: dto.cityId, isActive: true }, select: { id: true, defaultCurrency: true } }),
        tx.vendor.findFirst({ where: { id: dto.vendorId, status: 'APPROVED', cities: { some: { cityId: dto.cityId } } }, select: { id: true } }),
        tx.deliveryZone.findUnique({ where: { cityId: dto.cityId } }),
      ]);
      if (!address) throw new BadRequestException('عنوان التوصيل غير صالح');
      if (!city) throw new BadRequestException('المدينة غير متاحة');
      if (!vendor) throw new BadRequestException('المتجر غير متاح في هذه المدينة');
      if (!deliveryZone) throw new BadRequestException('لم يتم إعداد رسوم التوصيل لهذه المدينة بعد');
      const feeBase = Number(deliveryZone.feeBase);
      const feePerKm = Number(deliveryZone.feePerKm);
      let distanceKm: number | null = null;
      if (feePerKm > 0) {
        const distances = await tx.$queryRaw<Array<{ distanceKm: number | null }>>`
          SELECT CASE
            WHEN a."point" IS NULL OR vl."point" IS NULL THEN NULL
            ELSE ST_Distance(a."point", vl."point") / 1000.0
          END AS "distanceKm"
          FROM "Address" a
          CROSS JOIN "VendorLocation" vl
          WHERE a."id" = ${dto.addressId}
            AND a."userId" = ${customerId}
            AND vl."vendorId" = ${vendor.id}
        `;
        distanceKm = distances[0]?.distanceKm ?? null;
        if (distanceKm === null) throw new BadRequestException('حدد موقع عنوان التوصيل وموقع المتجر لحساب رسوم التوصيل لكل كيلومتر');
      }
      const deliveryFee = feeBase + Math.ceil(distanceKm ?? 0) * feePerKm;
      const products = await tx.product.findMany({ where: { id: { in: ids }, vendorId: vendor.id, isAvailable: true }, include: { translations: { where: { locale: 'ar' }, take: 1 } } });
      if (products.length !== ids.length) throw new BadRequestException('بعض المنتجات لم تعد متاحة');
      const byId = new Map(products.map(p => [p.id, p]));
      const subtotal = dto.items.reduce((sum, line) => {
        const p = byId.get(line.productId)!;
        if (p.currency !== city.defaultCurrency) throw new BadRequestException('عملة المنتج لا تطابق عملة المدينة');
        if (p.stockQty !== null && p.stockQty < line.quantity) throw new BadRequestException('الكمية المطلوبة غير متوفرة');
        return sum + Number(p.basePrice) * line.quantity;
      }, 0);
      // خصم المخزون داخل المعاملة نفسها لمنع بيع آخر قطعة مرتين عند وصول طلبين متزامنين.
      for (const line of dto.items) {
        const product = byId.get(line.productId)!;
        if (product.stockQty !== null) {
          const reserved = await tx.product.updateMany({
            where: { id: product.id, isAvailable: true, stockQty: { gte: line.quantity } },
            data: { stockQty: { decrement: line.quantity } },
          });
          if (reserved.count !== 1) throw new BadRequestException('نفدت كمية أحد المنتجات، حدّث السلة وحاول مجدداً');
        }
      }
      const order = await tx.order.create({ data: {
        orderNumber: `DRB-${Date.now().toString(36).toUpperCase()}-${randomBytes(2).toString('hex').toUpperCase()}`,
        type: 'VENDOR_ORDER', cityId: city.id, customerId, vendorId: vendor.id, addressId: address.id,
        currency: city.defaultCurrency, subtotal, deliveryFee, total: subtotal + deliveryFee, notes: dto.notes,
        items: { create: dto.items.map(line => { const p = byId.get(line.productId)!; return {
          productId: p.id, quantity: line.quantity, unitPrice: p.basePrice, currency: p.currency,
          nameSnapshot: p.translations[0]?.name ?? 'منتج',
        }; }) },
        payment: { create: { method: 'CASH_ON_DELIVERY', amount: subtotal + Number(deliveryZone.feeBase), currency: city.defaultCurrency } },
        statusHistory: { create: { status: 'PENDING', changedBy: customerId } },
      }, include: { items: true, payment: true } });
      return order;
    });
  }
  mine(userId: string) { return this.prisma.order.findMany({ where: { customerId: userId }, orderBy: { createdAt: 'desc' }, include: { items: true, payment: true, statusHistory: { orderBy: { createdAt: 'asc' } } } }); }
  async vendorOrders(userId: string) {
    const vendor = await this.prisma.vendor.findUnique({ where: { userId }, select: { id: true } });
    if (!vendor) throw new ForbiddenException();
    return this.prisma.order.findMany({ where: { vendorId: vendor.id }, orderBy: { createdAt: 'desc' }, include: { items: true, address: true, customer: { select: { name: true, phone: true } } } });
  }
  async driverMine(userId: string) { const driver = await this.prisma.driver.findUnique({ where: { userId }, select: { id: true } }); if (!driver) throw new ForbiddenException(); return this.prisma.order.findMany({ where: { driverId: driver.id }, orderBy: { createdAt: 'desc' }, include: { items: true, address: true, vendor: { include: { location: true, translations: true } } } }); }
  async availableForDriver(userId: string) { const driver = await this.prisma.driver.findUnique({ where: { userId }, select: { cityId: true, status: true, isOnline: true } }); if (!driver || driver.status !== 'APPROVED' || !driver.isOnline) throw new ForbiddenException('السائق غير متصل أو غير معتمد'); return this.prisma.order.findMany({ where: { cityId: driver.cityId, status: 'READY', driverId: null }, orderBy: { createdAt: 'asc' }, include: { items: true, vendor: { include: { location: true, translations: true } }, address: true } }); }
  async claim(userId: string, orderId: string) {
    const driver = await this.prisma.driver.findUnique({ where: { userId } });
    if (!driver || driver.status !== 'APPROVED' || !driver.isOnline) throw new ForbiddenException('السائق غير معتمد أو غير متصل');
    return this.prisma.$transaction(async tx => {
      const result = await tx.order.updateMany({ where: { id: orderId, cityId: driver.cityId, status: 'READY', driverId: null }, data: { driverId: driver.id, status: 'ASSIGNED' } });
      if (!result.count) throw new BadRequestException('الطلب لم يعد متاحاً');
      await tx.orderStatusHistory.create({ data: { orderId, status: 'ASSIGNED', changedBy: userId } });
      return tx.order.findUnique({ where: { id: orderId }, include: { items: true, address: true } });
    });
  }
  async updateStatus(userId: string, role: UserRole, orderId: string, status: OrderStatus) {
    const allowed: Record<string, OrderStatus[]> = {
      VENDOR: [OrderStatus.ACCEPTED, OrderStatus.PREPARING, OrderStatus.READY, OrderStatus.CANCELLED],
      DRIVER: [OrderStatus.PICKED_UP, OrderStatus.DELIVERED],
    };
    if (!allowed[role]?.includes(status)) throw new BadRequestException('انتقال الحالة غير مسموح');
    const order = await this.prisma.order.findUnique({ where: { id: orderId }, include: { vendor: true, driver: true } });
    if (!order) throw new NotFoundException('الطلب غير موجود');
    if (role === 'VENDOR' && order.vendor?.userId !== userId) throw new ForbiddenException();
    if (role === 'DRIVER' && order.driver?.userId !== userId) throw new ForbiddenException();
    const transitions: Record<string, OrderStatus[]> = {
      PENDING: [OrderStatus.ACCEPTED, OrderStatus.CANCELLED], ACCEPTED: [OrderStatus.PREPARING, OrderStatus.CANCELLED],
      PREPARING: [OrderStatus.READY], ASSIGNED: [OrderStatus.PICKED_UP], PICKED_UP: [OrderStatus.DELIVERED],
    };
    if (!transitions[order.status]?.includes(status)) throw new BadRequestException('تسلسل حالة الطلب غير صحيح');
    return this.prisma.$transaction(async tx => {
      const changed = await tx.order.updateMany({ where: { id: orderId, status: order.status }, data: { status } });
      if (!changed.count) throw new BadRequestException('تم تحديث الطلب من مستخدم آخر؛ أعد تحميله');
      await tx.orderStatusHistory.create({ data: { orderId, status, changedBy: userId } });
      return tx.order.findUnique({ where: { id: orderId } });
    });
  }
}

