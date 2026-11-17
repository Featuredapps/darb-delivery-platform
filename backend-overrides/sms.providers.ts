import { InternalServerErrorException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SmsProvider } from './sms.provider';

/** للتطوير فقط: يطبع الرمز في سجل التطوير. */
export class ConsoleSmsProvider implements SmsProvider {
  private readonly logger = new Logger('ConsoleSms');
  async send(phone: string, message: string): Promise<void> {
    this.logger.warn(`[DEV] SMS to ${phone}: ${message}`);
  }
}

/** تكامل MsgPlus لإرسال OTP إلى الأرقام السورية. */
export class MsgPlusSmsProvider implements SmsProvider {
  private readonly logger = new Logger(MsgPlusSmsProvider.name);

  constructor(private readonly config: ConfigService) {}

  async send(phone: string, message: string): Promise<void> {
    const apiKey = this.config.get<string>('MSGPLUS_API_KEY');
    const senderName = this.config.get<string>('MSGPLUS_SENDER_NAME');
    const templateId = Number(this.config.get<string>('MSGPLUS_TEMPLATE_ID', '3'));
    const match = message.match(/(?:^|\\D)(\\d{6})(?:\\D|$)/);
    const normalized = phone.replace(/[\\s()-]/g, '').replace(/^\\+/, '');

    if (!apiKey || !senderName || !Number.isInteger(templateId) || templateId <= 0 || !match || !/^9639\\d{8}$/.test(normalized)) {
      throw new InternalServerErrorException('إعدادات إرسال رمز التحقق غير مكتملة');
    }

    let response: Response;
    try {
      response = await fetch('https://sms.msgplus.tech/api/v1/send', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'X-Timestamp': Math.floor(Date.now() / 1000).toString(),
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          sender_name: senderName,
          template_id: templateId,
          numbers: [normalized],
          vars: { code: match[1] },
        }),
        signal: AbortSignal.timeout(10000),
      });
    } catch {
      throw new InternalServerErrorException('تعذر الاتصال بمزود رسائل التحقق');
    }

    if (!response.ok) {
      const status = response.status;
      const responseText = await response.text().catch(() => '');
      let providerMessage = '';
      try {
        const body = JSON.parse(responseText) as Record<string, unknown>;
        const candidate = body.message ?? body.error ?? body.detail;
        if (typeof candidate === 'string') providerMessage = candidate.slice(0, 240);
      } catch {
        // Ignore non-JSON provider bodies.
      }

      // Keep provider diagnostics useful without exposing phone numbers, OTPs, or credentials.
      this.logger.error(`MsgPlus rejected OTP request: HTTP ${status}; provider_message=${providerMessage || 'not provided'}`);

      const reason = status === 400 ? 'توقيت خادم إرسال الرسائل غير صحيح'
        : status === 401 ? 'مفتاح MsgPlus غير صحيح أو غير مفعّل'
        : status === 403 ? 'اسم المرسل أو قالب الرسالة غير معتمد لحساب MsgPlus'
        : status === 422 ? 'رفض MsgPlus الطلب: تحقق من صيغة الرقم ومتغير القالب code والرصيد'
        : status === 429 ? 'طلبات SMS كثيرة؛ حاول لاحقاً'
        : 'فشل إرسال رسالة التحقق';
      throw new InternalServerErrorException(providerMessage ? `${reason} (تفاصيل المزود: ${providerMessage})` : reason);
    }

    // MsgPlus documents 202 Accepted as successful queueing.
    if (response.status !== 202) {
      this.logger.warn(`MsgPlus returned unexpected success status: ${response.status}`);
    }
  }
}

/** مزود HTTP عام للتوافق مع مزودين آخرين. */
export class HttpSmsProvider implements SmsProvider {
  constructor(private readonly config: ConfigService) {}
  async send(phone: string, message: string): Promise<void> {
    const res = await fetch(this.config.getOrThrow<string>('SMS_API_URL'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${this.config.getOrThrow<string>('SMS_API_KEY')}` },
      body: JSON.stringify({ to: phone, message }),
      signal: AbortSignal.timeout(10000),
    });
    if (!res.ok) throw new InternalServerErrorException('فشل إرسال رسالة التحقق');
  }
}
