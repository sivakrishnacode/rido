import { IsBoolean, IsEnum, IsOptional, IsString, Length } from 'class-validator';

import { Role } from '../../../generated/prisma/enums.js';

/** PATCH /admin/users/:id body. */
export class UpdateUserDto {
  @IsOptional()
  @IsString()
  @Length(2, 60)
  name?: string;

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
