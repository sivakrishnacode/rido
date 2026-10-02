import { Transform } from 'class-transformer';
import { IsIn, IsOptional, Matches } from 'class-validator';

import { NormalizePhone } from '../../../core/validation/normalize-phone.js';

/** The app signing in: decides which role an admin's token gets ([loginRole]). */
export const LOGIN_APPS = ['passenger', 'driver', 'admin'] as const;
export type LoginApp = (typeof LOGIN_APPS)[number];

/** POST /auth/verify body. */
export class VerifyOtpDto {
  @NormalizePhone()
  @Matches(/^(\+91)?[6-9]\d{9}$/, { message: 'Enter a valid 10-digit Indian mobile number' })
  phone: string;

  @Matches(/^\d{6}$/, { message: 'OTP must be 6 digits' })
  code: string;

  /**
   * Which app is signing in: `passenger`, `driver` or `admin` (any case; the admin panel sent `ADMIN` before). Only
   * the admin panel gets an ADMIN token. A DRIVER login still needs POST /drivers to register a vehicle.
   */
  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? value.toLowerCase() : value))
  @IsIn(LOGIN_APPS, { message: 'app must be passenger, driver or admin' })
  app?: LoginApp;
}
