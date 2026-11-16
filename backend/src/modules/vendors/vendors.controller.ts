import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { VendorsService } from './vendors.service';
@Controller('vendors')
export class VendorsController {
  constructor(private readonly vendors: VendorsService) {}
  @Get('mine') @UseGuards(JwtAuthGuard, RolesGuard) @Roles(UserRole.VENDOR)
  mine(@CurrentUser() user: { id: string }) { return this.vendors.mine(user.id); }
  @Get() list(@Query('cityId') cityId?: string, @Query('locale') locale = 'ar') {
    return this.vendors.list(cityId, locale);
  }
  @Get(':id') get(@Param('id') id: string, @Query('locale') locale = 'ar') {
    return this.vendors.get(id, locale);
  }
}
