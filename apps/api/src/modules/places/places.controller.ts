import { Controller, Get, ParseFloatPipe, Query } from '@nestjs/common';

import { Public } from '../../core/auth/public.decorator.js';
import type { Place } from '../../generated/prisma/client.js';
import { PlacesService } from './places.service.js';

/** P-08 search, P-09 reverse geocode. */
@Public()
@Controller('places')
export class PlacesController {
  constructor(private readonly places: PlacesService) {}

  @Get()
  search(@Query('q') q = ''): Promise<Place[]> {
    return this.places.search(q);
  }

  @Get('reverse')
  reverse(
    @Query('lat', ParseFloatPipe) lat: number,
    @Query('lng', ParseFloatPipe) lng: number,
  ): Promise<{ place: Place | null; isInServiceArea: boolean }> {
    return this.places.reverse({ lat, lng });
  }
}
