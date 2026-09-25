import { Matches } from 'class-validator';

/** POST /auth/otp body. Indian mobile number, 10 digits (with or without +91). */
export class SendOtpDto {
  @Matches(/^(\+91)?[6-9]\d{9}$/, { message: 'Enter a valid 10-digit Indian mobile number' })
  phone: string;
}
