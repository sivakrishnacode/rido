import { IsOptional, Matches } from 'class-validator';

/** Ride OTP (start) or delivery OTP (complete). */
export class OtpDto {
  @IsOptional()
  @Matches(/^\d{4}$/, { message: 'OTP must be 4 digits' })
  otp?: string;
}
