import { Type } from 'class-transformer';
import { IsEnum, IsOptional, ValidateNested } from 'class-validator';

import { VehicleKind } from '../../../generated/prisma/enums.js';
import { PointDto } from '../../fares/dto/point.dto.js';

/** POST /maps/route body. */
export class RouteQueryDto {
  @ValidateNested()
  @Type(() => PointDto)
  from: PointDto;

  @ValidateNested()
  @Type(() => PointDto)
  to: PointDto;

  @IsOptional()
  @IsEnum(VehicleKind)
  vehicleKind?: VehicleKind;
}
