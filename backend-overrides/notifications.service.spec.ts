import { NotificationsService } from './notifications.service';
describe('NotificationsService', () => {
  const prisma: any = { userDevice: { upsert: jest.fn().mockResolvedValue({ id: 'device-1' }), deleteMany: jest.fn().mockResolvedValue({ count: 1 }), findMany: jest.fn().mockResolvedValue([]) }, vendor: { findUnique: jest.fn() } };
  const config: any = { get: jest.fn().mockReturnValue(undefined) };
  let service: NotificationsService;
  beforeEach(() => { jest.clearAllMocks(); service = new NotificationsService(prisma, config); });
  it('registers an FCM token for the authenticated user', async () => {
    await expect(service.register('user-1', 'fcm-token-long-enough', 'android')).resolves.toEqual({ id: 'device-1' });
    expect(prisma.userDevice.upsert).toHaveBeenCalled();
  });
  it('allows users to unregister only their own token', async () => {
    await expect(service.unregister('user-1', 'fcm-token-long-enough')).resolves.toEqual({ success: true });
    expect(prisma.userDevice.deleteMany).toHaveBeenCalledWith({ where: { userId: 'user-1', token: 'fcm-token-long-enough' } });
  });
  it('keeps order workflows independent when Firebase credentials are absent', async () => {
    await expect(service.notifyCustomer('user-1', 'Order', 'Updated', { type: 'ORDER_STATUS' })).resolves.toBeUndefined();
    expect(prisma.userDevice.findMany).not.toHaveBeenCalled();
  });
});
