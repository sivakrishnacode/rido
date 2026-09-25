import { Body, Controller, Delete, Get, HttpCode, Param, Patch, Post } from '@nestjs/common';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { CurrentUser } from '../../core/auth/current-user.decorator.js';
import type { EmergencyContact, SavedPlace, User } from '../../generated/prisma/client.js';
import { CreateContactDto } from './dto/create-contact.dto.js';
import { SavedPlaceDto } from './dto/saved-place.dto.js';
import { UpdateProfileDto } from './dto/update-profile.dto.js';
import { UsersService } from './users.service.js';

/** P-05, P-23, P-23b, P-24. */
@Controller('me')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get()
  me(@CurrentUser() user: AuthUser): Promise<User> {
    return this.users.me(user.userId);
  }

  @Patch()
  update(@CurrentUser() user: AuthUser, @Body() body: UpdateProfileDto): Promise<User> {
    return this.users.update(user.userId, body);
  }

  @Post('emergency-contacts')
  addContact(@CurrentUser() user: AuthUser, @Body() body: CreateContactDto): Promise<EmergencyContact> {
    return this.users.addContact(user.userId, body);
  }

  @Delete('emergency-contacts/:id')
  @HttpCode(204)
  removeContact(@CurrentUser() user: AuthUser, @Param('id') id: string): Promise<void> {
    return this.users.removeContact(user.userId, id);
  }

  @Post('saved-places')
  addPlace(@CurrentUser() user: AuthUser, @Body() body: SavedPlaceDto): Promise<SavedPlace> {
    return this.users.addPlace(user.userId, body);
  }

  @Delete('saved-places/:id')
  @HttpCode(204)
  removePlace(@CurrentUser() user: AuthUser, @Param('id') id: string): Promise<void> {
    return this.users.removePlace(user.userId, id);
  }
}
