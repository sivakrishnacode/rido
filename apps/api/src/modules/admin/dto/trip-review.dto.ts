import { IsBoolean, IsOptional, IsString, Length } from 'class-validator';

/** PATCH /admin/trips/:id/review: clear (or set) the needs-review flag, with an optional note. */
export class TripReviewDto {
  @IsBoolean()
  needsReview: boolean;

  @IsOptional()
  @IsString()
  @Length(1, 300)
  note?: string;
}
