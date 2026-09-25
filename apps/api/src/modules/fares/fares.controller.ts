import { Body, Controller, HttpCode, Post } from '@nestjs/common';

import { Public } from '../../core/auth/public.decorator.js';
import { TripKind } from '../../generated/prisma/enums.js';
import { QuoteRequestDto } from './dto/quote-request.dto.js';
import type { FareQuote } from './fare-engine.js';
import { FaresService } from './fares.service.js';

/** Fare quotes (P-10 / PP-06). Public so the app can show prices before login. */
@Controller('fares')
export class FaresController {
  constructor(private readonly fares: FaresService) {}

  @Public()
  @Post('quote')
  @HttpCode(200)
  quote(@Body() body: QuoteRequestDto): { quotes: FareQuote[] } {
    return { quotes: this.fares.quoteAll({ pickup: body.pickup, drop: body.drop, kind: body.kind ?? TripKind.RIDE }) };
  }
}
