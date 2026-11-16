import { InternalServerErrorException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SmsProvider } from './sms.provider';

/** للتطوير: يطبع الرسالة في الـ console بدل إرسالها */
export class ConsoleSmsProvider implements SmsProvider {
  private readonly logger = new Logger('ConsoleSms');

  async send(phone: string, message: string): Promise<void> {
    this.logger.warn(`[DEV] SMS to ${phone}: ${message}`);
  }
}

/**
 * مزود HTTP عام. عدّل الشكل (body/headers) حسب مزود SMS المحلي الذي تتعاقد معه.
 */
export class HttpSmsProvider implements SmsProvider {
  constructor(private readonly config: ConfigService) {}

  async send(phone: string, message: string): Promise<void> {
    const res = await fetch(this.config.getOrThrow<string>('SMS_API_URL'), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this.config.getOrThrow<string>('SMS_API_KEY')}`,
      },
      body: JSON.stringify({ to: phone, message }),
      signal: AbortSignal.timeout(10_000),
    });

    if (!res.ok) {
      throw new InternalServerErrorException('فشل إرسال رسالة التحقق');
    }
  }
}

