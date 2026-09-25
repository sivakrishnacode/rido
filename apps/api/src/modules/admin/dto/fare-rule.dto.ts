import { IsBoolean, IsInt, IsNumber, IsOptional, Max, Min } from 'class-validator';

/** PUT /admin/cities/:id/fares/:vehicleKind body. */
export class FareRuleDto {
  @IsInt()
  @Min(0)
  @Max(10_000)
  base: number;

  @IsNumber()
  @Min(0)
  @Max(500)
  perKm: number;

  @IsNumber()
  @Min(0)
  @Max(100)
  perMin: number;

  @IsInt()
  @Min(0)
  @Max(20_000)
  minFare: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
