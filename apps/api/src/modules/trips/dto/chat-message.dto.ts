import { IsString, Length } from 'class-validator';

/** POST /trips/:id/messages body. */
export class ChatMessageDto {
  @IsString()
  @Length(1, 500)
  text: string;
}
