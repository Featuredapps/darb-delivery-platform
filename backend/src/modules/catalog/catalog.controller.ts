import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { IsBoolean, IsInt, IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CatalogService } from './catalog.service';
class CreateProductDto {
  @IsString() name!: string;
  @IsOptional() @IsString() description?: string;
  @Type(() => Number) @IsNumber() @Min(0) price!: number;
  @IsOptional() @IsString() currency?: string;
  @IsOptional() @IsString() imageUrl?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) stockQty?: number;
}
@Controller()
export class CatalogController {
  constructor(private readonly catalog: CatalogService) {}
  @Get('vendors/:vendorId/products') list(@Param('vendorId') vendorId: string, @Query('locale') locale = 'ar') {
    return this.catalog.list(vendorId, locale);
  }
  @Post('vendor/products') @UseGuards(JwtAuthGuard, RolesGuard) @Roles(UserRole.VENDOR)
  create(@CurrentUser() user: { id: string }, @Body() dto: CreateProductDto) { return this.catalog.create(user.id, dto); }
}
