import { ArrayMaxSize, IsArray, IsString } from 'class-validator';

/** PUT /admin/cities/:id/service-cells body: the full list of H3 cells. */
export class CellsDto {
  @IsArray()
  @ArrayMaxSize(20_000)
  @IsString({ each: true })
  cells: string[];
}
