import { IsEnum, IsOptional, Matches } from 'class-validator';

import { Role } from '../../../generated/prisma/enums.js';

import { NormalizePhone } from '../../../core/validation/normalize-phone.js';

/** POST /auth/verify body. */
export class VerifyOtpDto {
  @NormalizePhone()
  @Matches(/^(\+91)?[6-9]\d{9}$/, { message: 'Enter a valid 10-digit Indian mobile number' })
  phone: string;

  @Matches(/^\d{6}$/, { message: 'OTP must be 6 digits' })
  code: string;

  /** Which app is signing in; a DRIVER login still needs POST /drivers to register a vehicle. */
  @IsOptional()
  @IsEnum(Role)
  app?: Role;
}
