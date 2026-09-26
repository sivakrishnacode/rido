import { IsIn, IsOptional } from 'class-validator';

import { EARNINGS_PERIODS, type EarningsPeriod } from '../driver-earnings.service.js';

/** GET /drivers/me/earnings query. */
export class EarningsQueryDto {
  @IsOptional()
  @IsIn(EARNINGS_PERIODS)
  period?: EarningsPeriod;
}
