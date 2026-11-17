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

/** تكامل MsgPlus API v1 لإرسال OTP باستخدام القالب 1 والمتغير P1. */
export class MsgPlusSmsProvider implements SmsProvider {
  private readonly logger = new Logger(MsgPlusSmsProvider.name);

  constructor(private readonly config: ConfigService) {}

  async send(phone: string, message: string): Promise<void> {
    const apiKey = this.config.get<string>('MSGPLUS_API_KEY');
    const senderIdRaw = this.config.get<string>('MSGPLUS_SENDER_ID');
    const senderId = Number(senderIdRaw);
    const templateId = 1;
    const match = message.match(/(?:^|\D)(\d{6})(?:\D|$)/);
    const normalized = phone.replace(/[\s()-]/g, '').replace(/^\+/, '');

    if (!apiKey || !senderIdRaw || !Number.isInteger(senderId) || senderId <= 0 || !match || !/^9639\d{8}$/.test(normalized)) {
      throw new InternalServerErrorException('إعدادات إرسال رمز التحقق غير مكتملة أو معرّف المرسل غير رقمي');
    }

    let response: Response;
    try {
      response = await fetch('https://sms.msgplus.tech/api/v1/send', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'X-Timestamp': String(Math.floor(Date.now() / 1000)),
          'Content-Type': 'application/json',
          Accept: 'application/json',
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

    if (response.status !== 202) {
      const status = response.status;
      // لا نسجل نص رد المزود لأنه قد يحتوي على أرقام أو رموز تحقق أو بيانات حساب.
      this.logger.error(`MsgPlus rejected OTP request: HTTP ${status}`);

      const reason = status === 400 ? 'توقيت طلب MsgPlus غير صحيح أو ترويسة X-Timestamp مفقودة'
        : status === 401 ? 'مفتاح MsgPlus غير صحيح أو غير مفعّل'
        : status === 403 ? 'معرّف المرسل أو قالب الرسالة غير معتمد'
        : status === 404 ? 'مسار MsgPlus API v1 غير موجود'
        : status === 422 ? 'رفض MsgPlus متغير القالب P1 أو رقم الهاتف أو الرصيد'
        : status === 429 ? 'طلبات SMS كثيرة؛ حاول لاحقاً'
        : 'فشل إرسال رسالة التحقق';
      throw new InternalServerErrorException(reason);
    }

    try {
      const result = await response.json() as { success?: boolean };
      if (result.success !== true) {
        throw new InternalServerErrorException('لم يؤكد MsgPlus قبول رسالة التحقق');
      }
    } catch (error) {
      if (error instanceof InternalServerErrorException) throw error;
      throw new InternalServerErrorException('استجابة MsgPlus غير صالحة');
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
