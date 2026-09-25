import { ForbiddenException, Inject, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

import type { JwtPayload } from '../../core/auth/auth-user.js';
import type { Env } from '../../core/config/env.js';
import { ENV } from '../../core/config/env.token.js';
import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { User } from '../../generated/prisma/client.js';
import { Role } from '../../generated/prisma/enums.js';
import { OtpService } from './otp.service.js';

/** Result of a successful OTP login. */
export interface LoginResult {
  readonly accessToken: string;
  readonly isNewUser: boolean;
  readonly user: User;
  readonly driverId?: string;
}

/** Phone + OTP sign-in for both apps; issues JWTs. */
@Injectable()
export class AuthService {
  constructor(
    private readonly otp: OtpService,
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  static normalise(phone: string): string {
    return `+91${phone.replace(/^\+91/, '')}`;
  }

  async verify(params: { phone: string; code: string }): Promise<LoginResult> {
    const phone = AuthService.normalise(params.phone);
    if (!(await this.otp.verify(phone, params.code))) throw new UnauthorizedException('Incorrect OTP');
    const existing = await this.prisma.user.findUnique({ where: { phone }, include: { driver: true } });
    if (existing?.isBlocked) throw new ForbiddenException(existing.blockedReason ?? 'Your account is blocked. Contact support.');
    const created = existing ?? (await this.prisma.user.create({ data: { phone }, include: { driver: true } }));
    // Phones in ADMIN_PHONES always sign in as ADMIN (admin panel).
    const isAdmin = this.env.adminPhones.includes(phone);
    const user = isAdmin && created.role !== Role.ADMIN
      ? await this.prisma.user.update({ where: { id: created.id }, data: { role: Role.ADMIN }, include: { driver: true } })
      : created;
    const accessToken = await this.issueToken({ sub: user.id, role: user.role, driverId: user.driver?.id });
    return { accessToken, isNewUser: !existing || !existing.name, user, driverId: user.driver?.id };
  }

  /** Signs a JWT (also used after a role change, e.g. driver registration). */
  issueToken(payload: JwtPayload): Promise<string> {
    return this.jwt.signAsync({ ...payload });
  }
}
