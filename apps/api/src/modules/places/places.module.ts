import { Module } from '@nestjs/common';

import { PlacesController } from './places.controller.js';
import { PlacesService } from './places.service.js';

/** Search and reverse geocoding. */
@Module({ controllers: [PlacesController], providers: [PlacesService], exports: [PlacesService] })
export class PlacesModule {}
