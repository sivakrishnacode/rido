import { Module } from '@nestjs/common';

import { CoreModule } from './core/core.module.js';
import { AdminModule } from './modules/admin/admin.module.js';
import { AppConfigModule } from './modules/app-config/app-config.module.js';
import { AuthModule } from './modules/auth/auth.module.js';
import { DriversModule } from './modules/drivers/drivers.module.js';
import { FaresModule } from './modules/fares/fares.module.js';
import { MapsModule } from './modules/maps/maps.module.js';
import { GeoModule } from './modules/geo/geo.module.js';
import { SettingsModule } from './modules/settings/settings.module.js';
import { HealthModule } from './modules/health/health.module.js';
import { PlacesModule } from './modules/places/places.module.js';
import { RealtimeModule } from './modules/realtime/realtime.module.js';
import { SubscriptionsModule } from './modules/subscriptions/subscriptions.module.js';
import { SupportModule } from './modules/support/support.module.js';
import { TripsModule } from './modules/trips/trips.module.js';
import { UsersModule } from './modules/users/users.module.js';
import { NotificationsModule } from './modules/notifications/notifications.module.js';

/** Root module: one module per domain. */
@Module({
  imports: [
    CoreModule,
    SettingsModule,
    GeoModule,
    HealthModule,
    AppConfigModule,
    AuthModule,
    UsersModule,
    MapsModule,
    PlacesModule,
    FaresModule,
    DriversModule,
    SubscriptionsModule,
    TripsModule,
    RealtimeModule,
    SupportModule,
    AdminModule,
    NotificationsModule,
  ],
})
export class AppModule {}
