import { ServiceUnavailableException } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { AiRoleAssistantService } from './ai-role-assistant.service';

describe('AiRoleAssistantService role isolation', () => {
  const prisma: any = {
    driver: { findUnique: jest.fn(), count: jest.fn() },
    vendor: { findUnique: jest.fn(), count: jest.fn() },
    order: { count: jest.fn() },
    product: { count: jest.fn() },
    city: { count: jest.fn() },
  };
  const config: any = { get: jest.fn() };
  let service: AiRoleAssistantService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new AiRoleAssistantService(prisma, config);
  });

  it('builds driver context only from the authenticated driver profile and city', async () => {
    prisma.driver.findUnique.mockResolvedValue({ id: 'driver-1', cityId: 'city-1', status: 'APPROVED', isOnline: true, vehicleType: 'MOTORCYCLE' });
    prisma.order.count.mockResolvedValue(2);
    const context = await (service as any).buildContext({ id: 'user-1', role: UserRole.DRIVER });
    expect(prisma.driver.findUnique).toHaveBeenCalledWith(expect.objectContaining({ where: { userId: 'user-1' } }));
    expect(context).toEqual(expect.objectContaining({ activeOrders: 2, availableStoreOrders: 2, availablePeerDeliveries: 2 }));
    expect(prisma.vendor.findUnique).not.toHaveBeenCalled();
  });

  it('limits vendor context to the vendor owned by the authenticated user', async () => {
    prisma.vendor.findUnique.mockResolvedValue({ id: 'vendor-1', status: 'APPROVED', ratingAvg: 4.5 });
    prisma.order.count.mockResolvedValue(1);
    prisma.product.count.mockResolvedValue(3);
    const context = await (service as any).buildContext({ id: 'user-vendor', role: UserRole.VENDOR });
    expect(prisma.vendor.findUnique).toHaveBeenCalledWith(expect.objectContaining({ where: { userId: 'user-vendor' } }));
    expect(context).toEqual(expect.objectContaining({ pendingOrders: 1, availableProducts: 3 }));
    expect(prisma.driver.findUnique).not.toHaveBeenCalled();
  });

  it('uses aggregated operational counts for administrators without exposing customer records', async () => {
    prisma.driver.count.mockResolvedValue(1);
    prisma.vendor.count.mockResolvedValue(2);
    prisma.order.count.mockResolvedValue(4);
    prisma.city.count.mockResolvedValue(3);
    const context = await (service as any).buildContext({ id: 'admin-1', role: UserRole.ADMIN });
    expect(context).toEqual(expect.objectContaining({ pendingDrivers: 1, pendingVendors: 2, activeCities: 3 }));
    expect(prisma.order.findMany).toBeUndefined();
  });

  it('does not call the AI provider when the server key is missing', async () => {
    config.get.mockReturnValue(undefined);
    prisma.order.count.mockResolvedValue(0);
    await expect(service.ask({ id: 'customer-1', role: UserRole.CUSTOMER }, 'كيف طلبي؟')).rejects.toBeInstanceOf(ServiceUnavailableException);
  });
});
