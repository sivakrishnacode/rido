import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsInt,
  IsLatitude,
  IsLongitude,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

import { MAX_AREAS, MAX_HELPERS, MAX_PAUSE_MINUTES } from '../booking-prefs.js';

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

  /** Bike and scooter drivers: goods-bike parcel requests too (older apps; Services uses PUT …/services/:service). */
  @IsOptional()
  @IsBoolean()
  parcels?: boolean | null;

  /** Goods trucks: house shifting jobs too (the driver brings [helpers] helpers). */
  @IsOptional()
  @IsBoolean()
  shifting?: boolean | null;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(MAX_HELPERS)
  helpers?: number | null;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(MAX_AREAS)
  @ValidateNested({ each: true })
  @Type(() => AreaDto)
  areas?: AreaDto[] | null;
}

/** PUT /drivers/me/services/:service. On, or off for [pauseMinutes] (absent / null: until the driver starts it again). */
export class ServiceDto {
  @IsBoolean()
  on!: boolean;

  @IsOptional()
  @IsInt()
  @Min(5)
  @Max(MAX_PAUSE_MINUTES)
  pauseMinutes?: number | null;

  /** Why they paused it ("Too far", "Long waits"…), for us. */
  @IsOptional()
  @IsString()
  @MaxLength(40)
  reason?: string | null;

  /** Packers & Movers: the helpers they bring (switching it on). */
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(MAX_HELPERS)
  helpers?: number | null;
}
