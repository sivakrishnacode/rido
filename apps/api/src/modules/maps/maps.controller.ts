import { Body, Controller, HttpCode, Post } from '@nestjs/common';

import { Public } from '../../core/auth/public.decorator.js';
import { curvedFallback } from './curved-fallback.js';
import { RouteQueryDto } from './dto/route-query.dto.js';
import type { RoadRoute } from './google-maps.client.js';
import { MapsService } from './maps.service.js';

/**
 * Route for drawing the polyline (P-10, D-16). Call once per leg, never on a timer: live tracking
 * uses the driver's GPS over Socket.IO, not repeated Routes API calls.
 */
@Public()
@Controller('maps')
export class MapsController {
  constructor(private readonly maps: MapsService) {}

  @Post('route')
  @HttpCode(200)
  async route(@Body() body: RouteQueryDto): Promise<RoadRoute & { source: 'google' | 'estimate' }> {
    const road = await this.maps.route(body);
    if (road) return { ...road, source: 'google' };
    const est = await this.maps.estimate(body);
    return { ...est, encodedPolyline: '', points: curvedFallback(body.from, body.to), source: 'estimate' };
  }
}
