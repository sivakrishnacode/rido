import { Type } from 'class-transformer';
import { IsBoolean, IsEnum, IsObject, IsOptional, IsString, Length, Matches, ValidateNested } from 'class-validator';

import { ParcelPayer, PaymentMode, TripKind, VehicleKind, WomenDriverPref } from '../../../generated/prisma/enums.js';
import { PointDto } from '../../fares/dto/point.dto.js';

/** "Who's riding?": someone else takes the ride (rides only). */
export class RiderDto {
  @IsString()
  @Length(2, 60)
  name: string;

  @Matches(/^(\+91)?[6-9]\d{9}$/, { message: "Enter the rider's 10-digit mobile number" })
  phone: string;

  /** Lets the booking use Butterfly (women drivers). */
  @IsBoolean()
  isWoman: boolean;
}

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

  /** Butterfly (rides, women riders only): women drivers first (PREFERRED) or only (ONLY). Default NONE. */
  @IsOptional()
  @IsEnum(WomenDriverPref)
  womenDriver?: WomenDriverPref;

  /** Booked for someone else: the driver sees and calls this person. Default: the account holder rides. */
  @IsOptional()
  @ValidateNested()
  @Type(() => RiderDto)
  rider?: RiderDto;
}
