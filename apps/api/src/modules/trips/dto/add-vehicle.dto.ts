import { IsEnum } from 'class-validator';

import { VehicleKind } from '../../../generated/prisma/enums.js';

/** POST /trips/:id/also body: another vehicle to search for ("Book any"). */
export class AddVehicleDto {
  @IsEnum(VehicleKind)
  vehicleKind: VehicleKind;
}
