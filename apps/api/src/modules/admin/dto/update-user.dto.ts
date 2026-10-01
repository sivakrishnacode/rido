import { IsBoolean, IsEmail, IsEnum, IsOptional, IsString, Length, ValidateIf } from 'class-validator';

import { Role } from '../../../generated/prisma/enums.js';

/** PATCH /admin/users/:id body. */
export class UpdateUserDto {
  @IsOptional()
  @IsString()
  @Length(2, 60)
  name?: string;

  /** null clears it. */
  @IsOptional()
  @ValidateIf((_o, v) => v !== null)
  @IsEmail({}, { message: 'Enter a valid email' })
  email?: string | null;

  @IsOptional()
  @IsEnum(Role)
  role?: Role;

  @IsOptional()
  @IsBoolean()
  isBlocked?: boolean;

  @IsOptional()
  @IsString()
  @Length(3, 200)
  blockedReason?: string;
}
