import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { User } from '@prisma/client';
import { normalizeSyrianPhone } from '../../common/validators/syrian-phone';
import { PrismaService } from '../../prisma/prisma.service';
import { OtpService, OTP_TTL_SECONDS } from './otp.service';
import { VerifyOtpDto } from './dto/verify-otp.dto';

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly otp: OtpService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async requestOtp(rawPhone: string) {
    const phone = this.requireSyrianPhone(rawPhone);
    await this.otp.issue(phone);
    return { sent: true, expiresInSeconds: OTP_TTL_SECONDS };
  }

  async verifyOtp(dto: VerifyOtpDto) {
    const phone = this.requireSyrianPhone(dto.phone);
    await this.otp.verify(phone, dto.code);

    const user = await this.prisma.user.upsert({
      where: { phone },
      create: { phone, name: dto.name, locale: dto.locale ?? 'ar' },
      update: dto.name ? { name: dto.name } : {},
    });

    return {
      user: this.publicUser(user),
      tokens: await this.issueTokens(user),
    };
  }

  async refresh(refreshToken: string): Promise<TokenPair> {
    let payload: { sub: string; type?: string };
    try {
      payload = await this.jwt.verifyAsync(refreshToken, {
        secret: this.config.getOrThrow<string>('JWT_REFRESH_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Refresh token غير صالح');
    }

    if (payload.type !== 'refresh') throw new UnauthorizedException('Refresh token غير صالح');

    const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user) throw new UnauthorizedException();

    return this.issueTokens(user);
  }

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException();
    return this.publicUser(user);
  }

  private async issueTokens(user: User): Promise<TokenPair> {
    const accessToken = await this.jwt.signAsync(
      { sub: user.id, role: user.role, type: 'access' },
      { secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'), expiresIn: '15m' },
    );

    const refreshToken = await this.jwt.signAsync(
      { sub: user.id, type: 'refresh' },
      { secret: this.config.getOrThrow<string>('JWT_REFRESH_SECRET'), expiresIn: '30d' },
    );

    return { accessToken, refreshToken };
  }

  private requireSyrianPhone(raw: string): string {
    const phone = normalizeSyrianPhone(raw);
    if (!phone) {
      throw new BadRequestException('رقم الهاتف غير صالح. يجب أن يكون رقماً سورياً مثل +9639XXXXXXXX');
    }
    return phone;
  }

  private publicUser(user: User) {
    return { id: user.id, phone: user.phone, name: user.name, role: user.role, locale: user.locale };
  }
}

