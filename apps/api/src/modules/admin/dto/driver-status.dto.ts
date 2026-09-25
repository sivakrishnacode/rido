import { IsEnum } from 'class-validator';

import { DriverStatus } from '../../../generated/prisma/enums.js';

/** PATCH /admin/drivers/:id body (approve, reject, put on hold). */
export class DriverStatusDto {
  @IsEnum(DriverStatus)
  status: DriverStatus;
}
