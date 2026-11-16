import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { OtpService } from './otp.service';
import { SMS_PROVIDER, SmsProvider } from './sms/sms.provider';
import { ConsoleSmsProvider, HttpSmsProvider } from './sms/sms.providers';
import { JwtStrategy } from './strategies/jwt.strategy';

@Module({
  imports: [JwtModule.register({}), PassportModule],
  controllers: [AuthController],
  providers: [
    AuthService,
    OtpService,
    JwtStrategy,
    {
      provide: SMS_PROVIDER,
      inject: [ConfigService],
      useFactory: (config: ConfigService): SmsProvider =>
        config.get('NODE_ENV') === 'production'
          ? new HttpSmsProvider(config)
          : new ConsoleSmsProvider(),
    },
  ],
  exports: [AuthService],
})
export class AuthModule {}

