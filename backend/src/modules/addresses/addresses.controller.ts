import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { IsNumber, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AddressesService } from './addresses.service';
class CreateAddressDto {
  @IsOptional() @IsString() @MaxLength(40) label?: string;
  @IsString() @MaxLength(500) details!: string;
  @IsOptional() @IsNumber() @Min(-90) @Max(90) latitude?: number;
  @IsOptional() @IsNumber() @Min(-180) @Max(180) longitude?: number;
}
@Controller('addresses') @UseGuards(JwtAuthGuard, RolesGuard) @Roles(UserRole.CUSTOMER)
export class AddressesController {
  constructor(private readonly addresses:AddressesService){}
  @Get() list(@CurrentUser() user:{id:string}){return this.addresses.list(user.id);}
  @Post() create(@CurrentUser() user:{id:string},@Body() dto:CreateAddressDto){return this.addresses.create(user.id,dto);}
}
