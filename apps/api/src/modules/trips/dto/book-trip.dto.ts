import { Type } from 'class-transformer';
import { IsEnum, IsObject, IsOptional, ValidateNested } from 'class-validator';

import { ParcelPayer, PaymentMode, TripKind, VehicleKind } from '../../../generated/prisma/enums.js';
import { PointDto } from '../../fares/dto/point.dto.js';

/** POST /trips body (P-10 Book, PP-06 Book). */
export class BookTripDto {
  @IsEnum(TripKind)
  kind: TripKind;

  @IsEnum(VehicleKind)
  vehicleKind: VehicleKind;

  @ValidateNested()
  @Type(() => PointDto)
  pickup: PointDto;

  @ValidateNested()
  @Type(() => PointDto)
  drop: PointDto;

  @IsOptional()
  @IsEnum(PaymentMode)
  paymentMode?: PaymentMode;

  /** Parcel only: category, weight band, sender and receiver details. */
  @IsOptional()
  @IsObject()
  parcel?: Record<string, unknown>;

  @IsOptional()
  @IsEnum(ParcelPayer)
  payer?: ParcelPayer;
}
