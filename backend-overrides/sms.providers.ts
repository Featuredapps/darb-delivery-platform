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

/** تكامل MsgPlus لإرسال OTP إلى الأرقام السورية باستخدام القالب 1 والمتغير P1. */
export class MsgPlusSmsProvider implements SmsProvider {
  private readonly logger = new Logger(MsgPlusSmsProvider.name);

  constructor(private readonly config: ConfigService) {}

  async send(phone: string, message: string): Promise<void> {
    const apiKey = this.config.get<string>('MSGPLUS_API_KEY');
    const senderId = this.config.get<string>('MSGPLUS_SENDER_ID');
    const templateId = 1;
    const match = message.match(/(?:^|\D)(\d{6})(?:\D|$)/);
    const normalized = phone.replace(/[\s()-]/g, '').replace(/^\+/, '');

    if (!apiKey || !senderId || !match || !/^9639\d{8}$/.test(normalized)) {
      throw new InternalServerErrorException('إعدادات إرسال رمز التحقق غير مكتملة');
    }

    let response: Response;
    try {
      response = await fetch('https://sms.msgplus.tech/api/send', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          sender_id: senderId,
          template_id: templateId,
          numbers: [normalized],
          vars: { P1: match[1] },
        }),
        signal: AbortSignal.timeout(10000),
      });
    } catch {
      throw new InternalServerErrorException('تعذر الاتصال بمزود رسائل التحقق');
    }

    if (!response.ok) {
      const status = response.status;
      // لا نسجل نص رد المزود لأنه قد يحتوي على أرقام أو رموز تحقق أو بيانات حساب.
      this.logger.error(`MsgPlus rejected OTP request: HTTP ${status}`);

      const reason = status === 400 ? 'بيانات طلب MsgPlus غير صحيحة'
        : status === 401 ? 'مفتاح MsgPlus غير صحيح أو غير مفعّل'
        : status === 403 ? 'معرّف المرسل أو قالب الرسالة غير معتمد'
        : status === 404 ? 'مسار إرسال MsgPlus غير موجود؛ تحقق من تفعيل واجهة API'
        : status === 422 ? 'رفض MsgPlus متغير القالب P1 أو رقم الهاتف أو الطلب'
        : status === 429 ? 'طلبات SMS كثيرة؛ حاول لاحقاً'
        : 'فشل إرسال رسالة التحقق';
      throw new InternalServerErrorException(reason);
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
