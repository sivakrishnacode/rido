import { Global, Module } from '@nestjs/common';

import { SettingsService } from './settings.service.js';

/** Platform settings, available everywhere. */
@Global()
@Module({ providers: [SettingsService], exports: [SettingsService] })
export class SettingsModule {}
