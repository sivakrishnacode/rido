import { Body, Controller, HttpCode, Post } from '@nestjs/common';

import { LIMITS, RateLimit } from '../../core/rate-limit/rate-limit.decorator.js';
import { curvedFallback } from './curved-fallback.js';
import { RouteQueryDto } from './dto/route-query.dto.js';
import type { RoadRoute } from './google-maps.client.js';
import { MapsService } from './maps.service.js';

/**
 * Route for drawing the polyline (P-10, D-16). Call once per leg, never on a timer: live tracking
 * uses the driver's GPS over Socket.IO, not repeated Routes API calls. Signed in (any role), rate limited: a route
 * can be a paid Google call.
 */
@Controller('maps')
export class MapsController {
  constructor(private readonly maps: MapsService) {}

  @RateLimit(LIMITS.mapsRoute)
  @Post('route')
  @HttpCode(200)
  async route(@Body() body: RouteQueryDto): Promise<RoadRoute & { travelMin: number | null; source: 'google' | 'estimate' }> {
    const road = await this.maps.route(body);
    // travelMin: Google's traffic-aware minutes from the last 15 min (cache only: drawing a leg never pays for a refresh).
    if (road) return { ...road, travelMin: await this.maps.cachedTravelMin(body), source: 'google' };
    const est = await this.maps.estimate(body);
    return { ...est, travelMin: null, encodedPolyline: '', points: curvedFallback(body.from, body.to), source: 'estimate' };
  }
}
