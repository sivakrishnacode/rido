import { IsEnum, IsIn, IsOptional, IsString, Length } from 'class-validator';

import { AppKind } from '../../../generated/prisma/enums.js';

/** POST /me/devices body: the app's FCM registration token. */
export class RegisterDeviceDto {
  @IsString()
  @Length(20, 4096)
  token: string;

  @IsEnum(AppKind)
  app: AppKind;

  @IsOptional()
  @IsIn(['android', 'ios'])
  platform?: string;
}
