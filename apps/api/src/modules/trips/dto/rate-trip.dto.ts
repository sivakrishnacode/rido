import { IsInt, Max, Min } from 'class-validator';

/** POST /trips/:id/rate body (P-20). */
export class RateTripDto {
  @IsInt()
  @Min(1)
  @Max(5)
  rating: number;
}
