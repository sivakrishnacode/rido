import { Module } from '@nestjs/common';

import { MapsModule } from '../maps/maps.module.js';
import { FaresController } from './fares.controller.js';
import { FaresService } from './fares.service.js';

/** Fare engine and quote endpoint. */
@Module({ imports: [MapsModule], controllers: [FaresController], providers: [FaresService], exports: [FaresService] })
export class FaresModule {}
