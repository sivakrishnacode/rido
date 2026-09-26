import { Module } from '@nestjs/common';

import { AppConfigController } from './app-config.controller.js';

/** Public app configuration (plans switch, contribute page). */
@Module({ controllers: [AppConfigController] })
export class AppConfigModule {}
