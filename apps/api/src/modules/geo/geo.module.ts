import { Global, Module } from '@nestjs/common';

import { GeoController } from './geo.controller.js';
import { DemandService } from './demand.service.js';
import { GeoService } from './geo.service.js';
import { DriverMapService } from './driver-map.service.js';
import { HexStatsService } from './hex-stats.service.js';

/** H3 service areas and zones (global: fares, places and trips use it). */
@Global()
@Module({ controllers: [GeoController], providers: [GeoService, DemandService, HexStatsService, DriverMapService], exports: [GeoService, DemandService, HexStatsService] })
export class GeoModule {}
