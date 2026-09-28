import { Type } from 'class-transformer';
import { IsLatitude, IsLongitude, IsNumber, IsOptional, IsString, Length, Max, Min, ValidateNested } from 'class-validator';

/** Where the driver wants to head (home, the stand). The server adds when it switches off. */
export class GoToDto {
  @IsLatitude()
  lat: number;

  @IsLongitude()
  lng: number;

  @IsString()
  @Length(1, 80)
  name: string;
}

/** PUT /drivers/me/booking-preferences. Every field optional; null clears that filter. */
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
}
