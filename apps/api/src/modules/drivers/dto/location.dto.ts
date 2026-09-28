import { Type } from 'class-transformer';
import { ArrayMaxSize, IsArray, IsBoolean, IsLatitude, IsLongitude, IsNumber, IsOptional, Max, Min, ValidateNested } from 'class-validator';

import { MAX_BATCH_FIXES } from '../location-fix.js';

/**
 * Driver GPS fix. Old apps send only lat / lng; newer ones add the phone's timestamp (epoch ms), accuracy (m),
 * speed (m/s), heading (°) and whether the location is mocked. Values are clamped again by `sanitizeFix`.
 */
export class LocationDto {
  @IsLatitude()
  lat: number;

  @IsLongitude()
  lng: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  ts?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100_000)
  acc?: number;

  @IsOptional()
  @IsNumber()
  spd?: number;

  @IsOptional()
  @IsNumber()
  hdg?: number;

  @IsOptional()
  @IsBoolean()
  mock?: boolean;
}

/** POST /drivers/me/locations: fixes buffered while the socket was down, sent in one go. */
export class LocationBatchDto {
  @IsArray()
  @ArrayMaxSize(MAX_BATCH_FIXES)
  @ValidateNested({ each: true })
  @Type(() => LocationDto)
  fixes: LocationDto[];
}
