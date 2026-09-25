import { IsBoolean, IsInt, IsLatitude, IsLongitude, IsNumber, IsOptional, IsString, Length, Matches, Max, Min } from 'class-validator';

/** POST /admin/cities body. Service cells default to a circle of [radiusKm] around the centre. */
export class CreateCityDto {
  @Matches(/^[a-z0-9-]{2,40}$/, { message: 'id must be a lowercase slug, e.g. "tiruppur"' })
  id: string;

  @IsString()
  @Length(2, 60)
  name: string;

  @IsString()
  @Length(2, 60)
  state: string;

  @IsLatitude()
  centerLat: number;

  @IsLongitude()
  centerLng: number;

  @IsOptional()
  @IsInt()
  @Min(6)
  @Max(10)
  h3Resolution?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(60)
  radiusKm?: number;
}

/** PATCH /admin/cities/:id body. */
export class UpdateCityDto {
  @IsOptional()
  @IsString()
  @Length(2, 60)
  name?: string;

  @IsOptional()
  @IsString()
  @Length(2, 60)
  state?: string;

  @IsOptional()
  @IsLatitude()
  centerLat?: number;

  @IsOptional()
  @IsLongitude()
  centerLng?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
