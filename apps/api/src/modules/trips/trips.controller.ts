import { Body, Controller, ForbiddenException, Get, HttpCode, Param, Post } from '@nestjs/common';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { CurrentUser } from '../../core/auth/current-user.decorator.js';
import { Roles } from '../../core/auth/roles.decorator.js';
import type { Trip } from '../../generated/prisma/client.js';
import { Role } from '../../generated/prisma/enums.js';
import { BookTripDto } from './dto/book-trip.dto.js';
import { CancelTripDto } from './dto/cancel-trip.dto.js';
import { OtpDto } from './dto/otp.dto.js';
import { RateTripDto } from './dto/rate-trip.dto.js';
import { TripsService } from './trips.service.js';

/** Passenger: P-10 … P-22, PP-06 … PP-10. Driver: D-15 … D-22. */
@Controller('trips')
export class TripsController {
  constructor(private readonly trips: TripsService) {}

  @Roles(Role.PASSENGER)
  @Post()
  book(@CurrentUser() user: AuthUser, @Body() body: BookTripDto): Promise<Trip> {
    return this.trips.book(user.userId, body);
  }

  @Get()
  history(@CurrentUser() user: AuthUser): Promise<Trip[]> {
    return this.trips.history(user);
  }

  @Get(':id')
  get(@CurrentUser() user: AuthUser, @Param('id') id: string): Promise<Trip> {
    return this.trips.get(user, id);
  }

  @Post(':id/cancel')
  @HttpCode(200)
  cancel(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() body: CancelTripDto): Promise<Trip> {
    return this.trips.cancel(user, id, body.reason);
  }

  @Roles(Role.PASSENGER)
  @Post(':id/rate')
  @HttpCode(200)
  rate(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() body: RateTripDto): Promise<Trip> {
    return this.trips.rate(user.userId, id, body.rating);
  }

  @Roles(Role.DRIVER)
  @Post(':id/accept')
  @HttpCode(200)
  accept(@CurrentUser() user: AuthUser, @Param('id') id: string): Promise<Trip> {
    return this.trips.accept(TripsController.driverId(user), id);
  }

  @Roles(Role.DRIVER)
  @Post(':id/decline')
  @HttpCode(204)
  decline(@CurrentUser() user: AuthUser, @Param('id') id: string): Promise<void> {
    return this.trips.decline(TripsController.driverId(user), id);
  }

  @Roles(Role.DRIVER)
  @Post(':id/arrived')
  @HttpCode(200)
  arrived(@CurrentUser() user: AuthUser, @Param('id') id: string): Promise<Trip> {
    return this.trips.arrived(TripsController.driverId(user), id);
  }

  @Roles(Role.DRIVER)
  @Post(':id/start')
  @HttpCode(200)
  start(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() body: OtpDto): Promise<Trip> {
    return this.trips.start(TripsController.driverId(user), id, body.otp);
  }

  @Roles(Role.DRIVER)
  @Post(':id/complete')
  @HttpCode(200)
  complete(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() body: OtpDto): Promise<Trip> {
    return this.trips.complete(TripsController.driverId(user), id, body.otp);
  }

  private static driverId(user: AuthUser): string {
    if (!user.driverId) throw new ForbiddenException('Register as a driver first');
    return user.driverId;
  }
}
