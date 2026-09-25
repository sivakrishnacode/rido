import { IsBoolean, IsInt, IsOptional, Max, Min } from 'class-validator';

/** PATCH /admin/plans/:id body. */
export class UpdatePlanDto {
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100_000)
  price?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
