import { Transform, Type } from 'class-transformer';
import { IsBoolean, IsIn, IsInt, IsOptional, Max, Min } from 'class-validator';

import { HEX_STAT_RES, type HexStatRes } from '../../geo/hex-stats.service.js';

/** GET /admin/hex-stats query. */
export class HexStatsQueryDto {
  /** H3 resolution: 9 street, 8 neighbourhood (default), 7 district. */
  @IsOptional()
  @Type(() => Number)
  @IsIn(HEX_STAT_RES)
  res?: HexStatRes;

  /** IST hour 0–23; all hours when omitted. */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(23)
  hour?: number;

  @IsOptional()
  @IsIn(['busiest', 'slowest', 'fastest'])
  sort?: 'busiest' | 'slowest' | 'fastest';

  /** true = only pairs with enough trips to be used for ETAs. */
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  used?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(500)
  limit?: number;
}
