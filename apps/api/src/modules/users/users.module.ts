import { Module } from '@nestjs/common';

import { DriversModule } from '../drivers/drivers.module.js';
import { AccountDeletionService } from './account-deletion.service.js';
import { StoredFileRemover } from './stored-file-remover.js';
import { UsersController } from './users.controller.js';
import { UsersService } from './users.service.js';

/** Profile, emergency contacts, saved places and account deletion. */
@Module({
  imports: [DriversModule],
  controllers: [UsersController],
  providers: [UsersService, AccountDeletionService, StoredFileRemover],
  exports: [UsersService, AccountDeletionService],
})
export class UsersModule {}
