import { IsLatitude, IsLongitude, IsOptional, IsString, Length, Matches } from 'class-validator';

/**
 * POST /trips/:id/arrived and /complete body: the driver's GPS fix (else their last known position is used) and,
 * when they are outside the allowed radius, why they are continuing anyway.
 */
export class PositionCheckDto {
  @IsOptional()
  @IsLatitude()
  lat?: number;

  @IsOptional()
  @IsLongitude()
  lng?: number;

  @IsOptional()
  @IsString()
  @Length(3, 200)
  farReason?: string;
}

/** POST /trips/:id/complete: position check + the delivery OTP for parcels. */
export class CompleteTripDto extends PositionCheckDto {
  @IsOptional()
  @Matches(/^\d{4}$/, { message: 'OTP must be 4 digits' })
  otp?: string;
}
