import { Body, Controller, HttpCode, Post } from '@nestjs/common';

import { Public } from '../../core/auth/public.decorator.js';
import { TripKind } from '../../generated/prisma/enums.js';
import { QuoteRequestDto } from './dto/quote-request.dto.js';
import { FaresService, type QuoteWithEta } from './fares.service.js';

/** Fare quotes (P-10 / PP-06). Public so the app can show prices before login. */
@Controller('fares')
export class FaresController {
  constructor(private readonly fares: FaresService) {}

  @Public()
  @Post('quote')
  @HttpCode(200)
  async quote(@Body() body: QuoteRequestDto): Promise<{ quotes: QuoteWithEta[] }> {
    const quotes = await this.fares.quoteAll({ pickup: body.pickup, drop: body.drop, kind: body.kind ?? TripKind.RIDE });
    return { quotes: await this.fares.withPickupEta(quotes, body.pickup, { womenOnly: body.womenOnly ?? false }) };
  }
}
