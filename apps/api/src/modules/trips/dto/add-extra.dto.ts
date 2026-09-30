import { IsInt, Max, Min } from 'class-validator';

/** POST /trips/:id/extra body: the rider's extra on top of the quote, in all (more than before; see extra-fare.ts). */
export class AddExtraDto {
  @IsInt()
  @Min(1)
  @Max(5000)
  amount: number;
}
