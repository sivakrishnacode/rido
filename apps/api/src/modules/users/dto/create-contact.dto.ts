import { IsString, Length, Matches } from 'class-validator';

import { NormalizePhone } from '../../../core/validation/normalize-phone.js';

/** POST /me/emergency-contacts body (P-24b). */
export class CreateContactDto {
  @IsString()
  @Length(1, 60)
  name: string;

  @IsString()
  @Length(1, 30)
  relation: string;

  @NormalizePhone()

  @Matches(/^(\+91)?[6-9]\d{9}$/, { message: 'Enter a valid 10-digit Indian mobile number' })
  phone: string;
}
