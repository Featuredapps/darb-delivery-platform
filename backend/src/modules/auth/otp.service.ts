import {
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac, randomInt, timingSafeEqual } from 'crypto';
import type Redis from 'ioredis';
import { REDIS } from '../../redis/redis.module';
import { SMS_PROVIDER, SmsProvider } from './sms/sms.provider';

export const OTP_TTL_SECONDS = 300;
const MAX_ATTEMPTS = 5;
const MAX_SENDS_PER_HOUR = 5;
const SEND_WINDOW_SECONDS = 3600;

/**
 * إدارة رموز OTP في Redis:
 * - الرمز يُخزَّن كـ HMAC وليس كنص صريح
 * - صلاحية 5 دقائق
 * - حد 5 محاولات تحقق لكل رمز
 * - حد 5 طلبات إرسال لكل رقم في الساعة
 */
@Injectable()
export class OtpService {
  private readonly secret: string;

  constructor(
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(SMS_PROVIDER) private readonly sms: SmsProvider,
    config: ConfigService,
  ) {
    this.secret = config.getOrThrow<string>('OTP_SECRET');
  }

  async issue(phone: string): Promise<void> {
    const sendsKey = `otp:sends:${phone}`;
    const sends = await this.redis.incr(sendsKey);
    if (sends === 1) await this.redis.expire(sendsKey, SEND_WINDOW_SECONDS);
    if (sends > MAX_SENDS_PER_HOUR) {
      throw new HttpException(
        'تم تجاوز عدد طلبات الرمز، حاول لاحقاً',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const code = randomInt(0, 1_000_000).toString().padStart(6, '0');

    await this.redis
      .multi()
      .set(this.codeKey(phone), this.hash(phone, code), 'EX', OTP_TTL_SECONDS)
      .del(this.attemptsKey(phone))
      .exec();

    await this.sms.send(phone, `رمز التحقق الخاص بك: ${code}`);
  }

  async verify(phone: string, code: string): Promise<void> {
    const stored = await this.redis.get(this.codeKey(phone));
    if (!stored) {
      throw new UnauthorizedException('الرمز منتهي الصلاحية أو غير موجود');
    }

    const attemptsKey = this.attemptsKey(phone);
    const attempts = await this.redis.incr(attemptsKey);
    if (attempts === 1) await this.redis.expire(attemptsKey, OTP_TTL_SECONDS);

    if (attempts > MAX_ATTEMPTS) {
      await this.clear(phone);
      throw new HttpException(
        'تم تجاوز عدد المحاولات، اطلب رمزاً جديداً',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const expected = Buffer.from(stored);
    const actual = Buffer.from(this.hash(phone, code));
    const valid = expected.length === actual.length && timingSafeEqual(expected, actual);

    if (!valid) throw new UnauthorizedException('الرمز غير صحيح');

    await this.clear(phone);
  }

  private async clear(phone: string): Promise<void> {
    await this.redis.del(this.codeKey(phone), this.attemptsKey(phone));
  }

  private hash(phone: string, code: string): string {
    return createHmac('sha256', this.secret).update(`${phone}:${code}`).digest('hex');
  }

  private codeKey(phone: string) {
    return `otp:code:${phone}`;
  }

  private attemptsKey(phone: string) {
    return `otp:attempts:${phone}`;
  }
}

