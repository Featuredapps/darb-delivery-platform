import { Injectable, Inject, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import { cert, getApps, initializeApp, App } from 'firebase-admin/app';
import { getMessaging, Messaging } from 'firebase-admin/messaging';
@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private messaging?: Messaging;
  constructor(private readonly prisma: PrismaService, config: ConfigService) {
    const raw = config.get<string>('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!raw) return;
    try {
      const credentials = JSON.parse(raw);
      const app: App = getApps().find(x => x.name === 'darb-notifications') ??
        initializeApp({ credential: cert(credentials), projectId: credentials.project_id }, 'darb-notifications');
      this.messaging = getMessaging(app);
    } catch (error) {
      this.logger.error('Firebase Admin credentials are invalid; push delivery is disabled.');
    }
  }
  async register(userId: string, token: string, platform?: string) {
    return this.prisma.userDevice.upsert({
      where: { token },
      create: { userId, token, platform: platform?.slice(0, 20) },
      update: { userId, platform: platform?.slice(0, 20), updatedAt: new Date() },
      select: { id: true },
    });
  }
  async unregister(userId: string, token: string) {
    await this.prisma.userDevice.deleteMany({ where: { userId, token } });
    return { success: true };
  }
  async notifyVendor(vendorId: string, title: string, body: string, data: Record<string,string>) {
    const vendor = await this.prisma.vendor.findUnique({ where: { id: vendorId }, select: { userId: true } });
    if (vendor) await this.notifyUser(vendor.userId, title, body, data);
  }
  async notifyCustomer(customerId: string, title: string, body: string, data: Record<string,string>) {
    await this.notifyUser(customerId, title, body, data);
  }
  private async notifyUser(userId: string, title: string, body: string, data: Record<string,string>) {
    if (!this.messaging) return;
    const devices = await this.prisma.userDevice.findMany({ where: { userId }, select: { token: true } });
    if (!devices.length) return;
    let result;
    try {
      result = await this.messaging.sendEachForMulticast({
        tokens: devices.map(x => x.token), notification: { title, body }, data,
        android: { priority: 'high' },
      });
    } catch (error) {
      this.logger.error('Firebase push send failed; order processing will continue.');
      return;
    }
    const invalid = result.responses.flatMap((r, i) =>
      !r.success && ['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(r.error?.code ?? '')
        ? [devices[i].token] : []);
    if (invalid.length) await this.prisma.userDevice.deleteMany({ where: { token: { in: invalid } } });
  }
}
