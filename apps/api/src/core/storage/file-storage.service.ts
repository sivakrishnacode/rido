import { GetObjectCommand, NoSuchKey, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { BadRequestException, Inject, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { mkdir, stat, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import type { Readable } from 'node:stream';

import type { Env } from '../config/env.js';
import { ENV } from '../config/env.token.js';

/** An uploaded file as multer (memory storage) hands it over. */
export interface UploadedBlob {
  readonly originalname: string;
  readonly mimetype: string;
  readonly size: number;
  readonly buffer: Buffer;
}

export const MAX_UPLOAD_BYTES = 8 * 1024 * 1024;
const TYPES: Record<string, string> = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'application/pdf': 'pdf' };
const NAME = /^[0-9a-f-]{36}\.(jpg|png|webp|pdf)$/;
/** Key prefix in the bucket (room for other kinds of files later). */
const PREFIX = 'kyc/';

/**
 * KYC documents and images. Production: a private S3 bucket (`S3_BUCKET`), credentials from the EC2 instance role
 * (no keys on the server); the bucket encrypts every object by default (SSE-S3). Dev without a bucket: local disk
 * (`UPLOAD_DIR`).
 * Names are random UUIDs and files are only served to admins (`GET /v1/admin/files/:name`), never publicly.
 */
@Injectable()
export class FileStorageService {
  private readonly logger = new Logger(FileStorageService.name);
  private readonly s3: S3Client | null;

  constructor(@Inject(ENV) private readonly env: Env) {
    this.s3 = env.s3Bucket
      ? new S3Client({ region: env.s3Region, ...(env.s3Endpoint ? { endpoint: env.s3Endpoint, forcePathStyle: true } : {}) })
      : null;
    this.logger.log(env.s3Bucket ? `Uploads → s3://${env.s3Bucket}/${PREFIX}` : `Uploads → ${env.uploadDir} (no S3_BUCKET)`);
  }

  async save(file: UploadedBlob | undefined): Promise<string> {
    if (!file?.buffer?.length) throw new BadRequestException('Attach a photo or PDF of the document');
    const ext = TYPES[file.mimetype];
    if (!ext) throw new BadRequestException('Upload a JPG, PNG, WebP or PDF');
    if (file.size > MAX_UPLOAD_BYTES) throw new BadRequestException('File is larger than 8 MB');
    const name = `${randomUUID()}.${ext}`;
    if (this.s3) {
      await this.s3.send(
        new PutObjectCommand({
          Bucket: this.env.s3Bucket,
          Key: PREFIX + name,
          Body: file.buffer,
          ContentType: file.mimetype,
        }),
      );
    } else {
      await mkdir(this.env.uploadDir, { recursive: true });
      await writeFile(join(this.env.uploadDir, name), file.buffer);
    }
    return name;
  }

  /** Streams a stored file. With S3, files saved on disk before the switch are still found. */
  async open(name: string): Promise<{ stream: Readable; type: string; size: number }> {
    if (!NAME.test(name)) throw new NotFoundException('File not found');
    const type = Object.entries(TYPES).find(([, e]) => e === name.split('.').pop())![0];
    if (this.s3) {
      try {
        const obj = await this.s3.send(new GetObjectCommand({ Bucket: this.env.s3Bucket, Key: PREFIX + name }));
        return { stream: obj.Body as Readable, type: obj.ContentType ?? type, size: obj.ContentLength ?? 0 };
      } catch (e) {
        if (!(e instanceof NoSuchKey)) throw e;
      }
    }
    const path = join(this.env.uploadDir, name);
    const info = await stat(path).catch(() => null);
    if (!info) throw new NotFoundException('File not found');
    return { stream: createReadStream(path), type, size: info.size };
  }
}
