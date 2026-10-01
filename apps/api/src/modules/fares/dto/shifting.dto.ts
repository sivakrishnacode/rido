import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

import { VehicleKind } from '../../../generated/prisma/enums.js';
import { HOME_SIZES, type HomeSize, PACKING_LEVELS, type PackingLevel, SHIFTING_RATES } from '../goods-modes.js';
import { PointDto } from './point.dto.js';

/** One thing to move, as the rider typed it ("Double cot", 1, "comes apart"). */
export class ShiftingItemDto {
  @IsString()
  @MinLength(1)
  @MaxLength(60)
  name: string;

  @IsInt()
  @Min(1)
  @Max(50)
  qty: number;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  note?: string;
}

/** House shifting: what the mover is asked to do (goods-modes.ts ShiftingDetails). */
export class ShiftingDto {
  @IsIn(HOME_SIZES)
  homeSize: HomeSize;

  /** To another town (helpers at the travel rate, the vehicle by the km). */
  @IsBoolean()
  between: boolean;

  /** Typed by the rider, no catalogue. Needed to book; a quote doesn't need them. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(60)
  @ValidateNested({ each: true })
  @Type(() => ShiftingItemDto)
  items?: ShiftingItemDto[];

  @IsInt()
  @Min(0)
  @Max(SHIFTING_RATES.maxFloor)
  pickupFloor: number;

  @IsBoolean()
  pickupLift: boolean;

  @IsInt()
  @Min(0)
  @Max(SHIFTING_RATES.maxFloor)
  dropFloor: number;

  @IsBoolean()
  dropLift: boolean;

  @IsIn(PACKING_LEVELS)
  packing: PackingLevel;

  @IsInt()
  @Min(0)
  @Max(SHIFTING_RATES.maxDismantlePieces)
  dismantlePieces: number;

  @IsBoolean()
  unpack: boolean;

  @IsInt()
  @Min(0)
  @Max(SHIFTING_RATES.maxExtraHelpers)
  extraHelpers: number;
}

/** POST /fares/shifting-quote body. */
export class ShiftingQuoteDto {
  @ValidateNested()
  @Type(() => PointDto)
  pickup: PointDto;

  @ValidateNested()
  @Type(() => PointDto)
  drop: PointDto;

  @ValidateNested()
  @Type(() => ShiftingDto)
  shifting: ShiftingDto;

  /** A goods truck; default: the one suggested for the home size. */
  @IsOptional()
  @IsEnum(VehicleKind)
  vehicleKind?: VehicleKind;

  /** The slot start (ISO) the lines are for; default: tomorrow 9 am IST. */
  @IsOptional()
  @IsDateString()
  at?: string;
}
