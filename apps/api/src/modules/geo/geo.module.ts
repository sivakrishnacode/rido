import { Global, Module } from '@nestjs/common';

import { GeoController } from './geo.controller.js';
import { GeoService } from './geo.service.js';

/** H3 service areas and zones (global: fares, places and trips use it). */
@Global()
@Module({ controllers: [GeoController], providers: [GeoService], exports: [GeoService] })
export class GeoModule {}
