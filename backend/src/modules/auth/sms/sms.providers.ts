import { BadGatewayException, InternalServerErrorException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SmsProvider } from './sms.provider';

/** Development-only provider. Never use this provider in production. */
export class ConsoleSmsProvider implements SmsProvider {
  private readonly logger = new Logger('ConsoleSms');

  async send(phone: string, message: string): Promise<void> {
    this.logger.warn(`[DEV ONLY] SMS to ${phone}: ${message}`);
  }
}

/** SMS Syria REST API v1 provider. The API key stays on the server. */
export class HttpSmsProvider implements SmsProvider {
  private readonly logger = new Logger('SmsSyria');

  constructor(private readonly config: ConfigService) {}

  async send(phone: string, message: string): Promise<void> {
    const apiUrl = this.config.get<string>('SMS_API_URL', 'https://smssyria.net/api/v1/messages');
    const apiKey = this.config.get<string>('SMS_API_KEY');
    const senderId = this.config.get<string>('SMS_SENDER_ID');

    if (!apiKey || !senderId) {
      this.logger.error('SMS provider configuration is incomplete');
      throw new InternalServerErrorException('خدمة الرسائل غير مهيأة على الخادم');
    }

    // SMS Syria accepts 2-11 alphanumeric characters, or numeric sender IDs up to 16 digits.
    const validSender = /^[A-Za-z0-9]{2,11}$/.test(senderId) || /^\\d{2,16}$/.test(senderId);
    if (!validSender) {
      this.logger.error('SMS_SENDER_ID has an invalid format');
      throw new InternalServerErrorException('معرّف مرسل الرسائل غير صالح');
    }

    let response: Response;
    try {
      response = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({ to: phone, sender_id: senderId, message }),
        signal: AbortSignal.timeout(10_000),
      });
    } catch {
      this.logger.error('SMS provider request failed or timed out');
      throw new BadGatewayException('تعذر الوصول إلى مزود الرسائل، حاول لاحقاً');
    }

    if (!response.ok) {
      // Do not log provider response bodies: they may contain personal or billing information.
      const status = response.status;
      this.logger.error(`SMS provider rejected request (HTTP ${status})`);
      if (status === 401 || status === 402 || status === 422 || status === 503) {
        throw new BadGatewayException('رفض مزود الرسائل الطلب. تحقق من رصيد الحساب وإعدادات المرسل');
      }
      throw new BadGatewayException('فشل إرسال رسالة التحقق');
    }
  }
}
