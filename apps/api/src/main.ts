import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';

import { AppModule } from './app.module.js';
import { loadEnv } from './core/config/env.js';

/** Starts the Rido API on /v1 (REST) and /rt (Socket.IO). */
async function bootstrap(): Promise<void> {
  const env = loadEnv();
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('v1', { exclude: ['health', 'health/ready'] });
  app.enableCors({ origin: env.corsOrigins.includes('*') ? true : [...env.corsOrigins] });
  app.enableShutdownHooks();
  await app.listen(env.port, '0.0.0.0');
  Logger.log(`Rido API listening on :${env.port} (${env.nodeEnv})`, 'Bootstrap');
}

await bootstrap();
