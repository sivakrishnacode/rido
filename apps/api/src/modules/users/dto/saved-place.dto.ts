import { IsIn, IsLatitude, IsLongitude, IsOptional, IsString, Length } from 'class-validator';

/** POST /me/saved-places body (P-23b). */
export class SavedPlaceDto {
  @IsString()
  @Length(1, 40)
  label: string;

  @IsIn(['home', 'work', 'other'])
  kind: string;

  @IsString()
  @Length(1, 120)
  name: string;

  @IsString()
  @Length(1, 200)
  address: string;

  @IsLatitude()
  lat: number;

  @IsLongitude()
  lng: number;

  /** House / flat · landmark. */
  @IsOptional()
  @IsString()
  @Length(0, 200)
  note?: string;
}
