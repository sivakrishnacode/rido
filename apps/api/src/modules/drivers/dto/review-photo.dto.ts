import { IsBoolean, IsOptional, IsString, Length } from 'class-validator';

/** POST /admin/drivers/:id/photo body: approve or reject the photo waiting for review. */
export class ReviewPhotoDto {
  @IsBoolean()
  isApproved: boolean;

  @IsOptional()
  @IsString()
  @Length(3, 200)
  reason?: string;
}
