import { IsEnum, IsString, Length, Matches } from 'class-validator';

import { VehicleKind, WorkType } from '../../../generated/prisma/enums.js';

/** POST /drivers body (D-04 … D-06). */
export class RegisterDriverDto {
  @IsString()
  @Length(2, 60)
  name: string;

  @IsEnum(WorkType)
  workType: WorkType;

  @IsEnum(VehicleKind)
  vehicleKind: VehicleKind;

  @IsString()
  @Length(2, 60)
  vehicleModel: string;

  @IsString()
  @Length(0, 30)
  vehicleColor: string;

  /** Indian plate, e.g. "TN 37 AB 4521". */
  @Matches(/^[A-Z]{2}\s?\d{1,2}\s?[A-Z]{0,3}\s?\d{1,4}$/i, { message: 'Enter a valid number plate' })
  plate: string;

  @Matches(/^[\w.-]{2,}@[a-z]{2,}$/i, { message: 'Enter a valid UPI ID' })
  upiId: string;
}
