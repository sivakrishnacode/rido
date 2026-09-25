import { Module } from '@nestjs/common';

import { SupportController } from './support.controller.js';
import { SupportService } from './support.service.js';

/** Support topics and tickets. */
@Module({ controllers: [SupportController], providers: [SupportService] })
export class SupportModule {}
