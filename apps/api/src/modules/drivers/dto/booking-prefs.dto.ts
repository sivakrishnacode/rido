import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsLatitude,
  IsLongitude,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';

import { MAX_AREAS } from '../booking-prefs.js';

/** A saved place ("Home", the stand) for Go To / Stay In. */
export class AreaDto {
  @IsLatitude()
  lat: number;

  @IsLongitude()
  lng: number;

  @IsString()
  @Length(1, 80)
  name: string;
}

/** Where the driver wants to head (home, the stand). The server adds when it switches off. */
export class GoToDto extends AreaDto {}

/** The area the driver wants to stay in. The server adds when it switches off. */
export class StayInDto extends AreaDto {
  @IsNumber()
  @Min(1)
  @Max(20)
  radiusKm: number;
}

/**
 * PUT /drivers/me/booking-preferences. Every field optional; null clears it. Absent: the trip filters and the go-to
 * are cleared, while stayIn, parcels and areas keep what is stored (older apps don't send them).
 */
export class BookingPrefsDto {
  @IsOptional()
  @IsNumber()
  @Min(0.5)
  @Max(10)
  maxPickupKm?: number | null;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(50)
  minTripKm?: number | null;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(100)
  maxTripKm?: number | null;

  @IsOptional()
  @ValidateNested()
  @Type(() => GoToDto)
  goTo?: GoToDto | null;

  @IsOptional()
  @ValidateNested()
  @Type(() => StayInDto)
  stayIn?: StayInDto | null;

  /** Bike drivers: goods-bike parcel requests too. */
  @IsOptional()
  @IsBoolean()
  parcels?: boolean | null;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(MAX_AREAS)
  @ValidateNested({ each: true })
  @Type(() => AreaDto)
  areas?: AreaDto[] | null;
}
