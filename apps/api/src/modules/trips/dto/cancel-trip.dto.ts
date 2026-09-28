import { IsEnum, IsOptional, IsString, Length } from 'class-validator';

import { CancelCode } from '../../../generated/prisma/enums.js';

/**
 * POST /trips/:id/cancel body (S-03 / D-16 reasons): [code] and an optional [note]. Older app versions send only
 * [reason] (a reason text); it is mapped to a code (see cancel-codes.ts) and kept as the note.
 */
export class CancelTripDto {
  @IsOptional()
  @IsEnum(CancelCode)
  code?: CancelCode;

  @IsOptional()
  @IsString()
  @Length(1, 200)
  note?: string;

  @IsOptional()
  @IsString()
  @Length(2, 120)
  reason?: string;
}
