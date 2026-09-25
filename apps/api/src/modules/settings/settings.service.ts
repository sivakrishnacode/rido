import { BadRequestException, Injectable } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { SETTING_DEFAULTS, SettingKey, Settings } from './settings.defaults.js';

const CACHE_MS = 15_000;

/** Platform settings from the AppSetting table, merged over defaults and cached briefly. */
@Injectable()
export class SettingsService {
  private cache: { at: number; value: Settings } | null = null;

  constructor(private readonly prisma: PrismaService) {}

  async all(): Promise<Settings> {
    if (this.cache && Date.now() - this.cache.at < CACHE_MS) return this.cache.value;
    const rows = await this.prisma.appSetting.findMany();
    const value = { ...SETTING_DEFAULTS } as Settings;
    for (const r of rows) {
      if (r.key in SETTING_DEFAULTS) (value as Record<string, unknown>)[r.key] = r.value;
    }
    this.cache = { at: Date.now(), value };
    return value;
  }

  async get<K extends SettingKey>(key: K): Promise<Settings[K]> {
    return (await this.all())[key];
  }

  /** Updates known keys only, with type checks against the defaults. */
  async update(patch: Partial<Record<string, unknown>>): Promise<Settings> {
    for (const [key, v] of Object.entries(patch)) {
      if (!(key in SETTING_DEFAULTS)) throw new BadRequestException(`Unknown setting ${key}`);
      if (typeof v !== typeof SETTING_DEFAULTS[key as SettingKey]) throw new BadRequestException(`${key} must be a ${typeof SETTING_DEFAULTS[key as SettingKey]}`);
      await this.prisma.appSetting.upsert({ where: { key }, create: { key, value: v as Prisma.InputJsonValue }, update: { value: v as Prisma.InputJsonValue } });
    }
    this.cache = null;
    return this.all();
  }
}
