import { IsIn, IsLatitude, IsLongitude, IsOptional, IsString, Length } from 'class-validator';

/** POST /trips/:id/safety-check: the passenger's answer to "Is everything OK?" / "Did you reach safely?". */
export class SafetyCheckDto {
  @IsIn(['OK', 'HELP'])
  answer!: 'OK' | 'HELP';

  /** The SafetyEvent the push was about (from the push data / socket event). */
  @IsOptional()
  @IsString()
  @Length(1, 40)
  eventId?: string;

  @IsOptional()
  @IsLatitude()
  lat?: number;

  @IsOptional()
  @IsLongitude()
  lng?: number;
}
