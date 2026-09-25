import { Controller, Get, NotFoundException, Param, ParseFloatPipe, Query } from '@nestjs/common';

import { Public } from '../../core/auth/public.decorator.js';
import type { City } from '../../generated/prisma/client.js';
import { GeoService, PointInfo } from './geo.service.js';

/** Service areas for the apps: cities, their H3 cells and zones, and point checks. */
@Public()
@Controller()
export class GeoController {
  constructor(private readonly geo: GeoService) {}

  @Get('cities')
  cities(): Promise<Pick<City, 'id' | 'name' | 'state' | 'centerLat' | 'centerLng' | 'h3Resolution'>[]> {
    return this.geo.activeCities();
  }

  @Get('cities/:id/service-area')
  async serviceArea(@Param('id') id: string): Promise<NonNullable<Awaited<ReturnType<GeoService['serviceArea']>>>> {
    const area = await this.geo.serviceArea(id);
    if (!area) throw new NotFoundException('City not found');
    return area;
  }

  @Get('geo/check')
  check(@Query('lat', ParseFloatPipe) lat: number, @Query('lng', ParseFloatPipe) lng: number): Promise<PointInfo> {
    return this.geo.locate({ lat, lng });
  }
}
