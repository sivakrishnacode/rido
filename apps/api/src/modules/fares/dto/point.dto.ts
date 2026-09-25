import { IsLatitude, IsLongitude, IsOptional, IsString, MaxLength } from 'class-validator';

/** A map point, optionally tied to a known place id (e.g. "gandhipuram"). */
export class PointDto {
  @IsLatitude()
  lat: number;

  @IsLongitude()
  lng: number;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  placeId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  address?: string;
}
