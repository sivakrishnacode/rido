import { Type } from 'class-transformer';
import { IsBoolean, IsEnum, IsOptional, ValidateNested } from 'class-validator';

import { TripKind } from '../../../generated/prisma/enums.js';
import { PointDto } from './point.dto.js';

/** POST /fares/quote body. */
export class QuoteRequestDto {
  @ValidateNested()
  @Type(() => PointDto)
  pickup: PointDto;

  @ValidateNested()
  @Type(() => PointDto)
  drop: PointDto;

  /** RIDE (bike/auto/cab) or PARCEL (goods vehicles). Default RIDE. */
  @IsOptional()
  @IsEnum(TripKind)
  kind?: TripKind;

  /** Butterfly "only": count only women drivers for each vehicle's pickup ETA. */
  @IsOptional()
  @IsBoolean()
  womenOnly?: boolean;
}
