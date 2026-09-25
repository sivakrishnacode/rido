import { IsOptional, IsString, Length } from 'class-validator';

/** POST /tickets body (P-25b). */
export class CreateTicketDto {
  @IsString()
  @Length(2, 40)
  topic: string;

  @IsString()
  @Length(5, 500)
  description: string;

  @IsOptional()
  @IsString()
  tripId?: string;
}
