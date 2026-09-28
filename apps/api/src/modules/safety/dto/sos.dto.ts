import { IsIn, IsLatitude, IsLongitude, IsOptional, IsString, Length } from 'class-validator';

/** POST /trips/:id/sos: where the caller is (the phone's fix), optionally a short note. */
export class SosDto {
  @IsOptional()
  @IsLatitude()
  lat?: number;

  @IsOptional()
  @IsLongitude()
  lng?: number;

  @IsOptional()
  @IsString()
  @Length(1, 300)
  note?: string;
}

/** POST /admin/sos/:id/resolve. */
export class ResolveSosDto {
  @IsIn(['RESOLVED', 'FALSE_ALARM'])
  status!: 'RESOLVED' | 'FALSE_ALARM';

  @IsOptional()
  @IsString()
  @Length(1, 500)
  note?: string;
}
