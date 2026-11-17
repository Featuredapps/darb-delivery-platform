import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { OrderStatus } from '@prisma/client';
import { OrdersService } from './orders.service';

describe('OrdersService safety checks', () => {
  const prisma: any = {
    $transaction: jest.fn(),
    driver: { findUnique: jest.fn() },
    order: { findUnique: jest.fn(), updateMany: jest.fn() },
    orderStatusHistory: { create: jest.fn() },
  };
  let service: OrdersService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new OrdersService(prisma);
  });

  it('rejects an empty order before opening a transaction', async () => {
    await expect(service.create('customer-1', {
      cityId: 'city-1', addressId: 'address-1', vendorId: 'vendor-1', items: [],
    })).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('rejects duplicate product lines inside the transaction', async () => {
    prisma.$transaction.mockImplementation(async (callback: (tx: any) => unknown) =>
      callback({ address: { findFirst: jest.fn().mockResolvedValue({ id: 'address-1' }) },
        city: { findFirst: jest.fn().mockResolvedValue({ id: 'city-1', defaultCurrency: 'SYP' }) },
        vendor: { findFirst: jest.fn().mockResolvedValue({ id: 'vendor-1' }) },
        deliveryZone: { findFirst: jest.fn().mockResolvedValue({ feeBase: 100 }) },
      }),
    );
    await expect(service.create('customer-1', {
      cityId: 'city-1', addressId: 'address-1', vendorId: 'vendor-1',
      items: [{ productId: 'product-1', quantity: 1 }, { productId: 'product-1', quantity: 2 }],
    })).rejects.toBeInstanceOf(BadRequestException);
  });

  it('adds the rounded-up PostGIS distance fee to the order total', async () => {
    const create = jest.fn().mockResolvedValue({ id: 'order-1' });
    const tx: any = {
      address: { findFirst: jest.fn().mockResolvedValue({ id: 'address-1' }) },
      city: { findFirst: jest.fn().mockResolvedValue({ id: 'city-1', defaultCurrency: 'SYP' }) },
      vendor: { findFirst: jest.fn().mockResolvedValue({ id: 'vendor-1' }) },
      deliveryZone: { findUnique: jest.fn().mockResolvedValue({ feeBase: 100, feePerKm: 25 }) },
      $queryRaw: jest.fn().mockResolvedValue([{ distanceKm: 1.25 }]),
      product: { findMany: jest.fn().mockResolvedValue([{
        id: 'product-1', currency: 'SYP', basePrice: 50, stockQty: null,
        translations: [{ name: 'منتج' }],
      }]) },
      order: { create },
    };
    prisma.$transaction.mockImplementation(async (callback: (tx: any) => unknown) => callback(tx));

    await service.create('customer-1', {
      cityId: 'city-1', addressId: 'address-1', vendorId: 'vendor-1',
      items: [{ productId: 'product-1', quantity: 1 }],
    });

    expect(create).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ deliveryFee: 150, total: 200 }),
    }));
  });

  it('refuses per-kilometre pricing when either GPS point is missing', async () => {
    const create = jest.fn();
    const tx: any = {
      address: { findFirst: jest.fn().mockResolvedValue({ id: 'address-1' }) },
      city: { findFirst: jest.fn().mockResolvedValue({ id: 'city-1', defaultCurrency: 'SYP' }) },
      vendor: { findFirst: jest.fn().mockResolvedValue({ id: 'vendor-1' }) },
      deliveryZone: { findUnique: jest.fn().mockResolvedValue({ feeBase: 100, feePerKm: 25 }) },
      $queryRaw: jest.fn().mockResolvedValue([{ distanceKm: null }]),
      product: { findMany: jest.fn() },
      order: { create },
    };
    prisma.$transaction.mockImplementation(async (callback: (tx: any) => unknown) => callback(tx));

    await expect(service.create('customer-1', {
      cityId: 'city-1', addressId: 'address-1', vendorId: 'vendor-1',
      items: [{ productId: 'product-1', quantity: 1 }],
    })).rejects.toBeInstanceOf(BadRequestException);
    expect(create).not.toHaveBeenCalled();
  });

  it('uses an atomic READY/unassigned claim and rejects a lost race', async () => {
    prisma.driver.findUnique.mockResolvedValue({
      id: 'driver-1', cityId: 'city-1', status: 'APPROVED', isOnline: true,
    });
    const tx = {
      order: { updateMany: jest.fn().mockResolvedValue({ count: 0 }), findUnique: jest.fn() },
      orderStatusHistory: { create: jest.fn() },
    };
    prisma.$transaction.mockImplementation(async (callback: (tx: any) => unknown) => callback(tx));

    await expect(service.claim('driver-user-1', 'order-1')).rejects.toBeInstanceOf(BadRequestException);
    expect(tx.order.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: 'order-1', cityId: 'city-1', status: 'READY', driverId: null },
      data: { driverId: 'driver-1', status: 'ASSIGNED' },
    }));
    expect(tx.orderStatusHistory.create).not.toHaveBeenCalled();
  });

  it('blocks a vendor from changing another vendor order', async () => {
    prisma.order.findUnique.mockResolvedValue({
      id: 'order-1', status: 'PENDING',
      vendor: { userId: 'different-vendor-user' }, driver: null,
    });
    await expect(service.updateStatus('vendor-user-1', 'VENDOR', 'order-1', OrderStatus.ACCEPTED))
      .rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('rejects invalid status transitions before writing history', async () => {
    prisma.order.findUnique.mockResolvedValue({
      id: 'order-1', status: 'PENDING',
      vendor: { userId: 'vendor-user-1' }, driver: null,
    });
    await expect(service.updateStatus('vendor-user-1', 'VENDOR', 'order-1', OrderStatus.READY))
      .rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('rejects stale concurrent status updates', async () => {
    prisma.order.findUnique.mockResolvedValue({
      id: 'order-1', status: 'PENDING',
      vendor: { userId: 'vendor-user-1' }, driver: null,
    });
    const tx = {
      order: { updateMany: jest.fn().mockResolvedValue({ count: 0 }), findUnique: jest.fn() },
      orderStatusHistory: { create: jest.fn() },
    };
    prisma.$transaction.mockImplementation(async (callback: (tx: any) => unknown) => callback(tx));
    await expect(service.updateStatus('vendor-user-1', 'VENDOR', 'order-1', OrderStatus.ACCEPTED))
      .rejects.toBeInstanceOf(BadRequestException);
    expect(tx.orderStatusHistory.create).not.toHaveBeenCalled();
  });
});
