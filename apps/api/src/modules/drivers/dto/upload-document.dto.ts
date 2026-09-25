import { IsOptional, IsUrl } from 'class-validator';

/** POST /drivers/me/documents/:type body (D-08). The file itself goes to object storage. */
export class UploadDocumentDto {
  @IsOptional()
  @IsUrl({ require_tld: false })
  fileUrl?: string;
}
