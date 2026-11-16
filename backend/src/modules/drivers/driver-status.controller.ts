import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { IsBoolean, IsLatitude, IsLongitude, IsNumber } from 'class-validator';
import { Type } from 'class-transformer';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { DriversService } from './drivers.service';

class OnlineDto { @IsBoolean() isOnline!: boolean; }
class DriverLocationDto {
  @Type(() => Number) @IsNumber() @IsLatitude() latitude!: number;
  @Type(() => Number) @IsNumber() @IsLongitude() longitude!: number;
}

@Controller('drivers')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.DRIVER)
export class DriverStatusController {
  constructor(private readonly drivers: DriversService) {}
  @Get('me') me(@CurrentUser() user: { id: string }) { return this.drivers.me(user.id); }
  @Patch('online') setOnline(@CurrentUser() user: { id: string }, @Body() dto: OnlineDto) {
    return this.drivers.setOnline(user.id, dto.isOnline);
  }
  @Patch('location') updateLocation(@CurrentUser() user: { id: string }, @Body() dto: DriverLocationDto) {
    return this.drivers.updateLocation(user.id, dto.latitude, dto.longitude);
  }
}
