import { Body, Controller, Delete, Get, HttpCode, Param, ParseEnumPipe, Patch, Post, Put, UseInterceptors } from '@nestjs/common';

import { Roles } from '../../core/auth/roles.decorator.js';
import type { City, CityFareRule, Zone } from '../../generated/prisma/client.js';
import { Role, VehicleKind } from '../../generated/prisma/enums.js';
import { AdminCitiesService, type CityPricing } from './admin-cities.service.js';
import { AuditInterceptor } from './audit.interceptor.js';
import { CellsDto } from './dto/cells.dto.js';
import { CreateCityDto, UpdateCityDto } from './dto/city.dto.js';
import { FareRuleDto } from './dto/fare-rule.dto.js';
import { CreateZoneDto, UpdateZoneDto } from './dto/zone.dto.js';

/** Cities, H3 service areas, zones and per-city fares. */
@Roles(Role.ADMIN)
@UseInterceptors(AuditInterceptor)
@Controller('admin')
export class AdminCitiesController {
  constructor(private readonly cities: AdminCitiesService) {}

  @Get('cities')
  list(): Promise<City[]> {
    return this.cities.cities();
  }

  @Post('cities')
  create(@Body() body: CreateCityDto): Promise<City> {
    return this.cities.create(body);
  }

  @Get('cities/:id')
  get(@Param('id') id: string): Promise<City> {
    return this.cities.city(id);
  }

  @Patch('cities/:id')
  update(@Param('id') id: string, @Body() body: UpdateCityDto): Promise<City> {
    return this.cities.update(id, body);
  }

  @Delete('cities/:id')
  @HttpCode(204)
  remove(@Param('id') id: string): Promise<void> {
    return this.cities.remove(id);
  }

  @Put('cities/:id/service-cells')
  setCells(@Param('id') id: string, @Body() body: CellsDto): Promise<{ count: number; rejected: string[] }> {
    return this.cities.setServiceCells(id, body.cells);
  }

  @Post('cities/:id/zones')
  createZone(@Param('id') id: string, @Body() body: CreateZoneDto): Promise<Zone> {
    return this.cities.createZone(id, body);
  }

  @Patch('zones/:id')
  updateZone(@Param('id') id: string, @Body() body: UpdateZoneDto): Promise<Zone> {
    return this.cities.updateZone(id, body);
  }

  @Delete('zones/:id')
  @HttpCode(204)
  removeZone(@Param('id') id: string): Promise<void> {
    return this.cities.removeZone(id);
  }

  @Get('cities/:id/fares')
  fares(@Param('id') id: string): ReturnType<AdminCitiesService['fares']> {
    return this.cities.fares(id);
  }

  @Put('cities/:id/fares/:vehicleKind')
  setFare(
    @Param('id') id: string,
    @Param('vehicleKind', new ParseEnumPipe(VehicleKind)) kind: VehicleKind,
    @Body() body: FareRuleDto,
  ): Promise<CityFareRule> {
    return this.cities.setFare(id, kind, body);
  }

  @Delete('cities/:id/fares/:vehicleKind')
  @HttpCode(204)
  resetFare(@Param('id') id: string, @Param('vehicleKind', new ParseEnumPipe(VehicleKind)) kind: VehicleKind): Promise<void> {
    return this.cities.resetFare(id, kind);
  }

  /** Rentals, outstation, goods to another town and house shifting prices (each the city's own or built-in). */
  @Get('cities/:id/pricing')
  pricing(@Param('id') id: string): Promise<CityPricing> {
    return this.cities.pricing(id);
  }

  /** Sets one whole section (`rental`, `outstation`, `goodsOutstation`, `shifting`); checked in fares/pricing.ts. */
  @Put('cities/:id/pricing/:section')
  setPricing(@Param('id') id: string, @Param('section') section: string, @Body() body: unknown): Promise<CityPricing> {
    return this.cities.setPricing(id, section, body);
  }

  @Delete('cities/:id/pricing/:section')
  @HttpCode(204)
  resetPricing(@Param('id') id: string, @Param('section') section: string): Promise<void> {
    return this.cities.resetPricing(id, section);
  }
}
