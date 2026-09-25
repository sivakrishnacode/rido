import { ArrayMaxSize, IsArray, IsBoolean, IsEnum, IsHexColor, IsNumber, IsOptional, IsString, Length, Max, Min } from 'class-validator';

import { ZoneKind } from '../../../generated/prisma/enums.js';

/** POST /admin/cities/:id/zones body. */
export class CreateZoneDto {
  @IsString()
  @Length(2, 60)
  name: string;

  @IsEnum(ZoneKind)
  kind: ZoneKind;

  @IsArray()
  @ArrayMaxSize(5_000)
  @IsString({ each: true })
  cells: string[];

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(1.5)
  surgeMultiplier?: number;

  @IsOptional()
  @IsHexColor()
  color?: string;
}

/** PATCH /admin/zones/:id body. */
export class UpdateZoneDto {
  @IsOptional()
  @IsString()
  @Length(2, 60)
  name?: string;

  @IsOptional()
  @IsEnum(ZoneKind)
  kind?: ZoneKind;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5_000)
  @IsString({ each: true })
  cells?: string[];

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(1.5)
  surgeMultiplier?: number;

  @IsOptional()
  @IsHexColor()
  color?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
