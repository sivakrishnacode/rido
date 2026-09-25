import { IsBoolean, IsEmail, IsEnum, IsOptional, IsString, Length } from 'class-validator';

import { Gender } from '../../../generated/prisma/enums.js';

/** PATCH /me body (P-05, safety preferences). */
export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @Length(2, 60)
  name?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;

  @IsOptional()
  @IsBoolean()
  preferWomenDriver?: boolean;

  @IsOptional()
  @IsBoolean()
  autoShareTrips?: boolean;
}
