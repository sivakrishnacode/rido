import { Module } from '@nestjs/common';

import { MapsModule } from '../maps/maps.module.js';
import { PlacesController } from './places.controller.js';
import { PlacesService } from './places.service.js';

/** Search and reverse geocoding. */
@Module({ imports: [MapsModule], controllers: [PlacesController], providers: [PlacesService], exports: [PlacesService] })
export class PlacesModule {}
