import { IsNumber, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';
export class VendorApplicationDto {
  @IsString() @MaxLength(60) name!: string;
  @IsString() @MaxLength(40) type!: string;
  @IsUUID() cityId!: string;
  @IsOptional() @IsString() @MaxLength(500) description?: string;
  @IsOptional() @IsString() @MaxLength(300) address?: string;
  @IsOptional() @IsNumber() @Min(-90) @Max(90) latitude?: number;
  @IsOptional() @IsNumber() @Min(-180) @Max(180) longitude?: number;
}
