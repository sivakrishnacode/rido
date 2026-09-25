import { IsIn, IsOptional, IsString, Length } from 'class-validator';

/** POST /admin/drivers/:id/documents/:type body. */
export class DocumentReviewDto {
  @IsIn(['VERIFIED', 'REJECTED'])
  status: 'VERIFIED' | 'REJECTED';

  @IsOptional()
  @IsString()
  @Length(3, 200)
  reason?: string;
}
