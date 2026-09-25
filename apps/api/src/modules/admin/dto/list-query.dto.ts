import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

/** Common list query: ?page=1&pageSize=20&q=…&status=… */
export class ListQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize?: number;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  q?: string;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  status?: string;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  kind?: string;

  /** Users list: PASSENGER | DRIVER | ADMIN. */
  @IsOptional()
  @IsString()
  @MaxLength(20)
  role?: string;

  /** Users list: "true" | "false". */
  @IsOptional()
  @IsString()
  @MaxLength(5)
  blocked?: string;
}
