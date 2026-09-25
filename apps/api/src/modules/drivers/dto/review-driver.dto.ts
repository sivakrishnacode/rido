import { IsBoolean, IsEnum, IsOptional, IsString, Length } from 'class-validator';

import { KycDocType } from '../../../generated/prisma/enums.js';

/** POST /admin/drivers/:id/review body. */
export class ReviewDriverDto {
  @IsBoolean()
  isApproved: boolean;

  @IsOptional()
  @IsEnum(KycDocType)
  rejectType?: KycDocType;

  @IsOptional()
  @IsString()
  @Length(3, 200)
  reason?: string;
}
