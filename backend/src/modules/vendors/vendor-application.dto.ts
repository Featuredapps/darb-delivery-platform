import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
export class VendorApplicationDto {
  @IsString() @MaxLength(60) name!: string;
  @IsString() @MaxLength(40) type!: string;
  @IsUUID() cityId!: string;
  @IsOptional() @IsString() @MaxLength(500) description?: string;
  @IsOptional() @IsString() @MaxLength(300) address?: string;
}
