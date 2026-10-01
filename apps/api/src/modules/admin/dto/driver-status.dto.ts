import { IsEnum, IsOptional, IsString, Length } from 'class-validator';

import { DriverStatus } from '../../../generated/prisma/enums.js';

/** PATCH /admin/drivers/:id body (approve, reject, put on hold). The reason is pushed to the driver and kept in the audit log. */
export class DriverStatusDto {
  @IsEnum(DriverStatus)
  status: DriverStatus;

  @IsOptional()
  @IsString()
  @Length(3, 200)
  reason?: string;
}
