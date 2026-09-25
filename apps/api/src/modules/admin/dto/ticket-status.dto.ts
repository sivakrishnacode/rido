import { IsEnum } from 'class-validator';

import { TicketStatus } from '../../../generated/prisma/enums.js';

/** PATCH /admin/tickets/:id body. */
export class TicketStatusDto {
  @IsEnum(TicketStatus)
  status: TicketStatus;
}
