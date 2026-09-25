import { Controller, Get, Param, ParseFloatPipe, Query } from '@nestjs/common';

import { Public } from '../../core/auth/public.decorator.js';
import type { Place } from '../../generated/prisma/client.js';
import type { PlaceSuggestion, ResolvedPlace } from '../maps/google-maps.client.js';
import { PlacesService } from './places.service.js';

/** P-08 search (autocomplete + details), P-09 reverse geocode. */
@Public()
@Controller('places')
export class PlacesController {
  constructor(private readonly places: PlacesService) {}

  /** Seeded places only (no Google cost). */
  @Get()
  search(@Query('q') q = ''): Promise<Place[]> {
    return this.places.search(q);
  }

  /** Send the same `session` token for every keystroke of one search, then call details once. */
  @Get('autocomplete')
  autocomplete(@Query('q') q = '', @Query('session') session = ''): Promise<{ source: 'google' | 'local'; results: PlaceSuggestion[] }> {
    return this.places.autocomplete({ input: q, sessionToken: session || 'anonymous' });
  }

  @Get('details/:placeId')
  details(@Param('placeId') placeId: string, @Query('session') session?: string): Promise<ResolvedPlace | null> {
    return this.places.details({ placeId, sessionToken: session });
  }

  @Get('reverse')
  reverse(
    @Query('lat', ParseFloatPipe) lat: number,
    @Query('lng', ParseFloatPipe) lng: number,
  ): Promise<{ place: ResolvedPlace | null; isInServiceArea: boolean }> {
    return this.places.reverse({ lat, lng });
  }
}
