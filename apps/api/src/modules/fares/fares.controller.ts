import { BadRequestException, Body, Controller, Get, HttpCode, Post } from '@nestjs/common';

import { Public } from '../../core/auth/public.decorator.js';
import { RideMode, TripKind } from '../../generated/prisma/enums.js';
import { QuoteRequestDto } from './dto/quote-request.dto.js';
import { ShiftingQuoteDto } from './dto/shifting.dto.js';
import { FaresService, istDayAt, type QuoteWithEta, type ShiftingQuoteResult } from './fares.service.js';
import { RENTAL_PACKAGES, RENTAL_RATES } from './ride-modes.js';

/** Fare quotes (P-10 / PP-06). Public so the app can show prices before login. */
@Controller('fares')
export class FaresController {
  constructor(private readonly fares: FaresService) {}

  @Public()
  @Post('quote')
  @HttpCode(200)
  async quote(@Body() body: QuoteRequestDto): Promise<{ quotes: QuoteWithEta[] }> {
    const mode = body.rideMode ?? RideMode.LOCAL;
    if (mode !== RideMode.LOCAL) {
      // Rental / outstation: the cab tiers, each with the terms it agrees to (`modeTerms`).
      const quotes = await this.fares.modeQuotes({
        pickup: body.pickup,
        drop: body.drop,
        rideMode: mode,
        kind: body.kind,
        rentalPackageId: body.rentalPackageId,
        roundTrip: body.roundTrip,
        leaveAt: body.scheduledAt ? new Date(body.scheduledAt) : new Date(),
        returnAt: body.returnAt ? new Date(body.returnAt) : null,
      });
      return { quotes: await this.fares.withPickupEta(quotes, body.pickup, { womenOnly: body.womenOnly ?? false }) };
    }
    if (!body.drop) throw new BadRequestException('Choose where you are going');
    const quotes = await this.fares.quoteAll({ pickup: body.pickup, drop: body.drop, kind: body.kind ?? TripKind.RIDE });
    return { quotes: await this.fares.withPickupEta(quotes, body.pickup, { womenOnly: body.womenOnly ?? false }) };
  }

  /**
   * House shifting (PH-01 … PH-03): the price lines for the home size, floors, packing and extras at a slot (default
   * tomorrow 9 am), every goods truck's total, and the next 7 days' totals.
   */
  @Public()
  @Post('shifting-quote')
  @HttpCode(200)
  shiftingQuote(@Body() body: ShiftingQuoteDto): Promise<ShiftingQuoteResult> {
    const now = new Date();
    return this.fares.shiftingQuote({
      pickup: body.pickup,
      drop: body.drop,
      details: body.shifting,
      vehicleKind: body.vehicleKind,
      at: body.at ? new Date(body.at) : istDayAt(now, 1, 9),
      now,
    });
  }

  /** Rental packages (1 h / 10 km … 12 h / 120 km) with each cab tier's price and its rates past the package. */
  @Public()
  @Get('rental-packages')
  rentalPackages(): { packages: { id: string; hours: number; km: number; prices: Record<string, number> }[]; rates: Record<string, { extraKm: number; extraMin: number }> } {
    const tiers = Object.keys(RENTAL_RATES) as (keyof typeof RENTAL_RATES)[];
    return {
      packages: RENTAL_PACKAGES.map((p, i) => ({ ...p, prices: Object.fromEntries(tiers.map((t) => [t, RENTAL_RATES[t].prices[i]])) })),
      rates: Object.fromEntries(tiers.map((t) => [t, { extraKm: RENTAL_RATES[t].extraKm, extraMin: RENTAL_RATES[t].extraMin }])),
    };
  }
}
