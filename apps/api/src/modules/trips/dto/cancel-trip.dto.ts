import { IsOptional, IsString, Length } from 'class-validator';

/** POST /trips/:id/cancel body (S-03 reasons). */
export class CancelTripDto {
  @IsOptional()
  @IsString()
  @Length(2, 120)
  reason?: string;
}
