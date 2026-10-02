import { DeleteObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { Inject, Injectable, Logger } from '@nestjs/common';
import { unlink } from 'node:fs/promises';
import { join } from 'node:path';

import type { Env } from '../../core/config/env.js';
import { ENV } from '../../core/config/env.token.js';

/** Stored names (FileStorageService): a random UUID and the type. */
const NAME = /^[0-9a-f-]{36}\.(jpg|png|webp|pdf)$/;
/** Same key prefix as FileStorageService. */
const PREFIX = 'kyc/';

/**
 * Deletes files saved by FileStorageService (KYC documents, photos) when an account is deleted: from the S3 bucket
 * when one is set (the instance role needs s3:DeleteObject on `kyc/*`) and from the local upload folder (dev, and
 * files saved on disk before S3). Best effort: a failure is logged, never thrown.
 * TODO(core): belongs in FileStorageService as `remove(name)`; kept here while that file has another owner.
 */
@Injectable()
export class StoredFileRemover {
  private readonly logger = new Logger(StoredFileRemover.name);
  private readonly s3: S3Client | null;

  constructor(@Inject(ENV) private readonly env: Env) {
    this.s3 = env.s3Bucket
      ? new S3Client({ region: env.s3Region, ...(env.s3Endpoint ? { endpoint: env.s3Endpoint, forcePathStyle: true } : {}) })
      : null;
  }

  /** Removes every stored name in [names] (others, e.g. full URLs or empty values, are skipped). Returns how many. */
  async remove(names: readonly (string | null | undefined)[]): Promise<number> {
    const stored = [...new Set(names.filter((n): n is string => !!n && NAME.test(n)))];
    for (const name of stored) {
      if (this.s3) {
        await this.s3
          .send(new DeleteObjectCommand({ Bucket: this.env.s3Bucket, Key: PREFIX + name }))
          .catch((e: Error) => this.logger.warn(`S3 delete of ${name} failed: ${e.message}`));
      }
      await unlink(join(this.env.uploadDir, name)).catch((e: NodeJS.ErrnoException) => {
        if (e.code !== 'ENOENT') this.logger.warn(`Delete of ${name} failed: ${e.message}`);
      });
    }
    return stored.length;
  }
}
