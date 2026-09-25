import { IsDateString, IsEnum, IsOptional, IsString, Length } from 'class-validator';

import { AnnouncementAudience } from '../../../generated/prisma/enums.js';

/** POST /admin/announcements body. */
export class CreateAnnouncementDto {
  @IsEnum(AnnouncementAudience)
  audience: AnnouncementAudience;

  @IsString()
  @Length(3, 80)
  title: string;

  @IsString()
  @Length(3, 500)
  body: string;

  @IsOptional()
  @IsString()
  cityId?: string;

  @IsOptional()
  @IsDateString()
  endsAt?: string;
}
