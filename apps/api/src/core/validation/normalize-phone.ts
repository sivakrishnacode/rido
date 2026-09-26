import { Transform } from 'class-transformer';

/** "98430 12345", "+91-98430-12345", "9843012345" → "+919843012345" (then validated by the DTO's pattern). */
export function normalizePhone(value: unknown): unknown {
  if (typeof value !== 'string') return value;
  const compact = value.replace(/[\s()-]/g, '');
  return /^[6-9]\d{9}$/.test(compact) ? `+91${compact}` : compact;
}

/** DTO decorator: normalises an Indian mobile number before validation. */
export const NormalizePhone = (): PropertyDecorator => Transform(({ value }) => normalizePhone(value));
