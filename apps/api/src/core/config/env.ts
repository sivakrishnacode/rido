import { existsSync } from 'node:fs';

/** Validated runtime configuration read from environment variables. */
export interface Env {
  readonly nodeEnv: string;
  readonly port: number;
  readonly databaseUrl: string;
  readonly redisUrl: string;
  readonly jwtSecret: string;
  readonly jwtExpiresIn: string;
  /** Dev/demo: accept any 6-digit OTP except 000000 (matches the prototype apps). */
  readonly isOtpDevMode: boolean;
  readonly corsOrigins: readonly string[];
  /** Server-side Google Maps Platform key (Places, Geocoding, Routes). Empty = local fallback. */
  readonly googleMapsApiKey: string;
  /** Phones (+91…) that sign in as ADMIN (admin panel). */
  readonly adminPhones: readonly string[];
  /** Local fallback for uploaded files when no S3 bucket is configured (dev). */
  readonly uploadDir: string;
  /** Private S3 bucket for KYC documents and images. Empty = local disk ([uploadDir]). */
  readonly s3Bucket: string;
  readonly s3Region: string;
  /** Only for S3-compatible servers in dev (e.g. MinIO); empty = AWS. */
  readonly s3Endpoint: string;
  /** Firebase service-account JSON for FCM (from FIREBASE_SERVICE_ACCOUNT_B64, base64). Empty = push disabled. */
  readonly firebaseServiceAccount: string;
}

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable ${name}`);
  return value;
}

/** Reads and validates the environment once at start-up. */
export function loadEnv(): Env {
  // Local dev: read apps/api/.env if present (Docker passes real env vars instead).
  if (existsSync('.env')) process.loadEnvFile('.env');
  const nodeEnv = process.env.NODE_ENV ?? 'development';
  const jwtSecret = required('JWT_SECRET');
  if (nodeEnv === 'production' && jwtSecret.length < 32) {
    throw new Error('JWT_SECRET must be at least 32 characters in production');
  }
  return {
    nodeEnv,
    port: Number(process.env.PORT ?? 3000),
    databaseUrl: required('DATABASE_URL'),
    redisUrl: required('REDIS_URL'),
    jwtSecret,
    jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '30d',
    isOtpDevMode: (process.env.OTP_DEV_MODE ?? 'false') === 'true',
    corsOrigins: (process.env.CORS_ORIGINS ?? '*').split(',').map((o) => o.trim()),
    googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY ?? '',
    adminPhones: (process.env.ADMIN_PHONES ?? '')
      .split(',')
      .map((p) => p.trim())
      .filter(Boolean)
      .map((p) => `+91${p.replace(/^\+91/, '')}`),
    uploadDir: process.env.UPLOAD_DIR ?? './uploads',
    s3Bucket: process.env.S3_BUCKET ?? '',
    s3Region: process.env.S3_REGION ?? process.env.AWS_REGION ?? 'ap-south-1',
    s3Endpoint: process.env.S3_ENDPOINT ?? '',
    firebaseServiceAccount: process.env.FIREBASE_SERVICE_ACCOUNT_B64
      ? Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_B64, 'base64').toString('utf8')
      : '',
  };
}
