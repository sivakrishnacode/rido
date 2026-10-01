import { Type } from 'class-transformer';
import { IsEnum, IsLatitude, IsLongitude, IsOptional } from 'class-validator';

import { TripKind } from '../../../generated/prisma/enums.js';

/** GET /drivers/nearby?lat=&lng=[&trip=RIDE|PARCEL] */
export class NearbyQueryDto {
  @Type(() => Number)
  @IsLatitude()
  lat: number;

  @Type(() => Number)
  @IsLongitude()
  lng: number;

  @IsOptional()
  @IsEnum(TripKind)
  trip?: TripKind;
}
