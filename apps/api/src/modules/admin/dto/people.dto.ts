import { IsEnum, IsIn, IsOptional, IsString, Length, Matches } from 'class-validator';

import { VehicleKind, WorkType } from '../../../generated/prisma/enums.js';

/** POST /admin/users/:id/notes body. */
export class CreateNoteDto {
  @IsString()
  @Length(2, 1000)
  body: string;
}

/** POST /admin/users/:id/message body: a push to this person's phone. */
export class MessageDto {
  @IsString()
  @Length(3, 65)
  title: string;

  @IsString()
  @Length(3, 240)
  body: string;

  /** Which app gets it (default: the driver app for drivers, the rider app otherwise). */
  @IsOptional()
  @IsIn(['DRIVER', 'PASSENGER', 'BOTH'])
  app?: 'DRIVER' | 'PASSENGER' | 'BOTH';
}

/** PATCH /admin/drivers/:id/profile body: fix a driver's details for them (support calls). */
export class AdminDriverProfileDto {
  /** Only while the driver is offline (live locations are indexed per vehicle). */
  @IsOptional()
  @IsEnum(VehicleKind)
  vehicleKind?: VehicleKind;

  @IsOptional()
  @IsEnum(WorkType)
  workType?: WorkType;

  @IsOptional()
  @IsString()
  @Length(2, 60)
  vehicleModel?: string;

  @IsOptional()
  @IsString()
  @Length(0, 30)
  vehicleColor?: string;

  @IsOptional()
  @Matches(/^[A-Z]{2}\s?\d{1,2}\s?[A-Z]{0,3}\s?\d{1,4}$/i, { message: 'Enter a valid number plate' })
  plate?: string;

  @IsOptional()
  @Matches(/^[\w.-]{2,}@[a-z]{2,}$/i, { message: 'Enter a valid UPI ID' })
  upiId?: string;
}
