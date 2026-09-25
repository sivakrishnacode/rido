import { Module } from '@nestjs/common';

import { GoogleMapsClient } from './google-maps.client.js';
import { MapsController } from './maps.controller.js';
import { EtaService } from './eta.service.js';
import { MapsService } from './maps.service.js';

/** Google Maps Platform (Places, Geocoding, Routes) with Redis caching and local fallback. */
@Module({ controllers: [MapsController], providers: [GoogleMapsClient, MapsService, EtaService], exports: [MapsService, EtaService] })
export class MapsModule {}
