import { Controller, Get } from '@nestjs/common';

import { Public } from '../../core/auth/public.decorator.js';
import { SettingsService } from '../settings/settings.service.js';

export interface MonthlyCost {
  totalInr: number;
  /** Non-zero parts only, in a fixed order. */
  items: { label: string; amountInr: number }[];
}

export interface AppConfig {
  driverPlansEnabled: boolean;
  supportPhone: string;
  /** [monthlyCost] is null while no cost is entered. */
  contribute: { upiId: string; payeeName: string; note: string; monthlyCost: MonthlyCost | null };
}

/** Public settings both apps read at start-up: whether plans are on, and the contribute page. */
@Public()
@Controller('app-config')
export class AppConfigController {
  constructor(private readonly settings: SettingsService) {}

  @Get()
  async get(): Promise<AppConfig> {
    const s = await this.settings.all();
    const items = [
      { label: 'Servers & database', amountInr: s.costServersInr },
      { label: 'Maps', amountInr: s.costMapsInr },
      { label: 'SMS (OTP)', amountInr: s.costSmsInr },
      { label: 'Other', amountInr: s.costOtherInr },
    ].filter((i) => i.amountInr > 0);
    const totalInr = items.reduce((sum, i) => sum + i.amountInr, 0);
    return {
      driverPlansEnabled: s.driverPlansEnabled,
      supportPhone: s.supportPhone,
      contribute: {
        upiId: s.contributeUpiId.trim(),
        payeeName: s.contributePayeeName.trim(),
        note: s.contributeNote.trim(),
        monthlyCost: totalInr > 0 ? { totalInr, items } : null,
      },
    };
  }
}
