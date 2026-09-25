import { Body, Controller, Get, Param, Patch, Query, UseInterceptors } from '@nestjs/common';

import { Roles } from '../../core/auth/roles.decorator.js';
import type { KycDocument, User } from '../../generated/prisma/client.js';
import { Role } from '../../generated/prisma/enums.js';
import { AdminUsersService } from './admin-users.service.js';
import type { Paged } from './admin.types.js';
import { AuditInterceptor } from './audit.interceptor.js';
import { ListQueryDto } from './dto/list-query.dto.js';
import { UpdateUserDto } from './dto/update-user.dto.js';

/** User management and the KYC review queue. */
@Roles(Role.ADMIN)
@UseInterceptors(AuditInterceptor)
@Controller('admin')
export class AdminUsersController {
  constructor(private readonly users: AdminUsersService) {}

  /** ?role=PASSENGER|DRIVER|ADMIN&blocked=true|false&q=… */
  @Get('users')
  list(@Query() q: ListQueryDto): Promise<Paged<User>> {
    return this.users.users(q);
  }

  @Get('users/:id')
  get(@Param('id') id: string): Promise<User> {
    return this.users.user(id);
  }

  @Patch('users/:id')
  update(@Param('id') id: string, @Body() body: UpdateUserDto): Promise<User> {
    return this.users.update(id, body);
  }

  /** ?status=UNDER_REVIEW (default) | REJECTED | NOT_UPLOADED | VERIFIED */
  @Get('kyc')
  kyc(@Query() q: ListQueryDto): Promise<Paged<KycDocument>> {
    return this.users.kycQueue(q);
  }
}
