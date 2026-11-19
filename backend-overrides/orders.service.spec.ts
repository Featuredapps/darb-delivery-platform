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

  it('creates a peer-delivery order without vendor or catalog items', async () => {
    const create = jest.fn().mockResolvedValue({ id: 'peer-1', type: 'PEER_DELIVERY' });
    const tx: any = {
      address: { findFirst: jest.fn().mockResolvedValue({ id: 'address-1' }) },
      city: { findFirst: jest.fn().mockResolvedValue({ id: 'city-1', defaultCurrency: 'SYP' }) },
      
      order: { create },
    };
    prisma.$transaction.mockImplementation(async (callback: (tx: any) => unknown) => callback(tx));

    await service.createPeerDelivery('customer-1', {
      cityId: 'city-1', addressId: 'address-1', pickupAddress: 'شارع الجامعة، حلب', pickupLatitude: 36.2021, pickupLongitude: 37.1343,
    });

    expect(create).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({
        type: 'PEER_DELIVERY', status: 'PENDING', cityId: 'city-1',
        customerId: 'customer-1', addressId: 'address-1',
        pickupAddress: 'شارع الجامعة، حلب', pickupLatitude: 36.2021, pickupLongitude: 37.1343,
        subtotal: 0, deliveryFee: 0, total: 0,
        payment: { create: expect.objectContaining({ method: 'CASH_ON_DELIVERY', amount: 0, currency: 'SYP' }) },
        statusHistory: { create: { status: 'PENDING', changedBy: 'customer-1' } },
      }),
      include: { payment: true, address: true },
    }));
  });

  it('rejects a peer-delivery pickup address that is too short before opening a transaction', async () => {
    await expect(service.createPeerDelivery('customer-1', {
      cityId: 'city-1', addressId: 'address-1', pickupAddress: 'abc', pickupLatitude: 36.2, pickupLongitude: 37.1,
    })).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
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

  it('restores reserved finite stock exactly when a vendor cancellation succeeds', async () => {
    prisma.order.findUnique.mockResolvedValue({
      id: 'order-1', status: 'PENDING',
      vendor: { userId: 'vendor-user-1' }, driver: null,
      items: [{ productId: 'product-1', quantity: 3 }, { productId: 'product-2', quantity: 1 }],
    });
    const productUpdateMany = jest.fn().mockResolvedValue({ count: 1 });
    const tx = {
      order: { updateMany: jest.fn().mockResolvedValue({ count: 1 }), findUnique: jest.fn().mockResolvedValue({ id: 'order-1', status: 'CANCELLED' }) },
      product: { updateMany: productUpdateMany },
      orderStatusHistory: { create: jest.fn() },
    };
    prisma.$transaction.mockImplementation(async (callback: (tx: any) => unknown) => callback(tx));

    await service.updateStatus('vendor-user-1', 'VENDOR', 'order-1', OrderStatus.CANCELLED);

    expect(productUpdateMany).toHaveBeenNthCalledWith(1, {
      where: { id: 'product-1', stockQty: { not: null } },
      data: { stockQty: { increment: 3 } },
    });
    expect(productUpdateMany).toHaveBeenNthCalledWith(2, {
      where: { id: 'product-2', stockQty: { not: null } },
      data: { stockQty: { increment: 1 } },
    });
    expect(tx.orderStatusHistory.create).toHaveBeenCalledWith({
      data: { orderId: 'order-1', status: OrderStatus.CANCELLED, changedBy: 'vendor-user-1' },
    });
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

describe('Peer delivery offers', () => {
  const prisma: any = {
    $transaction: jest.fn(),
    driver: { findUnique: jest.fn() },
  };
  let service: OrdersService;
  beforeEach(() => { jest.clearAllMocks(); service = new OrdersService(prisma); });

  it('allows only an approved online driver to submit a positive offer', async () => {
    prisma.driver.findUnique.mockResolvedValue({ id: 'driver-1', cityId: 'city-1', status: 'APPROVED', isOnline: true });
    const upsert = jest.fn().mockResolvedValue({ id: 'offer-1', amount: 75 });
    const tx: any = {
      order: { findFirst: jest.fn().mockResolvedValue({ id: 'order-1', currency: 'SYP' }) },
      deliveryOffer: { upsert },
    };
    prisma.$transaction.mockImplementation(async (callback: (tx: any) => unknown) => callback(tx));

    await service.submitDeliveryOffer('driver-user-1', 'order-1', 75);

    expect(upsert).toHaveBeenCalledWith(expect.objectContaining({
      where: { orderId_driverId: { orderId: 'order-1', driverId: 'driver-1' } },
      create: expect.objectContaining({ orderId: 'order-1', driverId: 'driver-1', amount: 75, currency: 'SYP', status: 'PENDING' }),
    }));
  });

  it('rejects an offer with zero or negative amount before database access', async () => {
    await expect(service.submitDeliveryOffer('driver-user-1', 'order-1', 0)).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.driver.findUnique).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('assigns a peer order to exactly the selected driver and closes other pending offers', async () => {
    const orderUpdateMany = jest.fn().mockResolvedValue({ count: 1 });
    const offerUpdate = jest.fn();
    const offerUpdateMany = jest.fn();
    const historyCreate = jest.fn();
    const tx: any = {
      order: { findFirst: jest.fn().mockResolvedValue({ id: 'order-1' }), updateMany: orderUpdateMany, findUnique: jest.fn().mockResolvedValue({ id: 'order-1', status: 'ASSIGNED' }) },
      deliveryOffer: {
        findFirst: jest.fn().mockResolvedValue({ id: 'offer-1', driverId: 'driver-1', amount: 75, currency: 'SYP' }),
        update: offerUpdate, updateMany: offerUpdateMany,
      },
      payment: { updateMany: jest.fn() },
      orderStatusHistory: { create: historyCreate },
    };
    prisma.$transaction.mockImplementation(async (callback: (tx: any) => unknown) => callback(tx));

    await service.selectDeliveryOffer('customer-1', 'order-1', 'offer-1');

    expect(orderUpdateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: 'order-1', customerId: 'customer-1', status: 'PENDING', driverId: null },
      data: { driverId: 'driver-1', status: 'ASSIGNED', deliveryFee: 75, total: 75 },
    }));
    expect(offerUpdate).toHaveBeenCalledWith({ where: { id: 'offer-1' }, data: { status: 'ACCEPTED' } });
    expect(offerUpdateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { orderId: 'order-1', id: { not: 'offer-1' }, status: 'PENDING' },
      data: { status: 'REJECTED' },
    }));
    expect(historyCreate).toHaveBeenCalled();
  });

  it('rejects a selection if another customer session already claimed the order', async () => {
    const tx: any = {
      order: { findFirst: jest.fn().mockResolvedValue({ id: 'order-1' }), updateMany: jest.fn().mockResolvedValue({ count: 0 }) },
      deliveryOffer: { findFirst: jest.fn().mockResolvedValue({ id: 'offer-1', driverId: 'driver-1', amount: 75, currency: 'SYP' }) },
    };
    prisma.$transaction.mockImplementation(async (callback: (tx: any) => unknown) => callback(tx));
    await expect(service.selectDeliveryOffer('customer-1', 'order-1', 'offer-1')).rejects.toBeInstanceOf(BadRequestException);
  });
});
