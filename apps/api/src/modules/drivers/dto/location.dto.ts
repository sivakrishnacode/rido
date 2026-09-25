import { IsLatitude, IsLongitude } from 'class-validator';

/** Driver GPS fix. */
export class LocationDto {
  @IsLatitude()
  lat: number;

  @IsLongitude()
  lng: number;
}
