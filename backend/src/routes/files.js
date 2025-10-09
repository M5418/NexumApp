import express from 'express';
import {
  S3Client,
  ListObjectsV2Command,
  PutObjectCommand,
  GetObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { v4 as uuidv4 } from 'uuid';
import { z } from 'zod';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';

const router = express.Router();

// S3 config
const REGION = process.env.AWS_REGION || 'ca-central-1';
const BUCKET = process.env.S3_BUCKET || 'nexum-uploads';

// Important: ensure virtual-hosted–style HTTPS URLs are used (no path-style)
// Path-style causes 3xx redirects which break CORS preflight in browsers.
const s3Client = new S3Client({
  region: REGION,
  forcePathStyle: false, // explicitly prefer virtual-hosted style
});

const ALLOWED_EXTENSIONS = [
  // Images
  'jpg',
  'jpeg',
  'png',
  'webp',

  // Docs
  'pdf',

  // Video
  'mp4',

  // Audio
  'm4a',
  'mp3',
  'wav',
  'aac',
  'webm', // used by web audio recording (opus/webm)
];

// Content-Type mapping (used for GET URLs / metadata decisions if needed)
function getContentType(ext) {
  const map = {
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    png: 'image/png',
    webp: 'image/webp',
    pdf: 'application/pdf',
    mp4: 'video/mp4',
    m4a: 'audio/mp4',
    mp3: 'audio/mpeg',
    wav: 'audio/wav',
    aac: 'audio/aac',
    webm: 'audio/webm',
  };
  return map[ext.toLowerCase()] || 'application/octet-stream';
}

// Generate s3 key like u/<userId>/YYYY/MM/DD/<uuid>.<ext>
function generateS3Key(userId, ext) {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  const uuid = uuidv4();
  return `u/${userId}/${year}/${month}/${day}/${uuid}.${ext}`;
}

// POST /api/files/presign-upload
router.post('/presign-upload', async (req, res) => {
  try {
    const schema = z.object({ ext: z.string().min(1) });
    const { ext } = schema.parse(req.body);
    const extLower = (ext || '').toLowerCase();

    if (!ALLOWED_EXTENSIONS.includes(extLower)) {
      return fail(res, 'invalid_file_extension', 400);
    }

    const key = generateS3Key(req.user.id, extLower);
    const contentType = getContentType(extLower);

    // Generate a presigned PUT URL.
    // Do NOT bind ContentType in the signature to avoid browser/proxy mismatches
    // (some browsers tweak the header value). The client may still send Content-Type.
    const putCmd = new PutObjectCommand({
      Bucket: BUCKET,
      Key: key,
      // ContentType: contentType, // intentionally omitted for CORS robustness
    });
    const putUrl = await getSignedUrl(s3Client, putCmd, { expiresIn: 3600 });

    // Public-style URL (will only be readable if bucket/object policy allows)
    const publicUrl = `https://${BUCKET}.s3.${REGION}.amazonaws.com/${key}`;

    // Signed GET URL (works with private buckets)
    const signedGetTtl = parseInt(process.env.S3_SIGNED_GET_TTL || '604800', 10); // 7 days
    const getCmd = new GetObjectCommand({ Bucket: BUCKET, Key: key });
    const readUrl = await getSignedUrl(s3Client, getCmd, { expiresIn: signedGetTtl });

    return res.json(
      ok({
        key,
        putUrl,
        publicUrl,
        readUrl,
        // Optionally return suggested contentType for clients that want it
        suggestedContentType: contentType,
      })
    );
  } catch (error) {
    if (error instanceof z.ZodError) {
      return fail(res, 'validation_error', 400);
    }
    console.error('Presign error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// POST /api/files/confirm
router.post('/confirm', async (req, res) => {
  try {
    const schema = z.object({
      key: z.string().min(1),
      url: z.string().url(),
    });
    const { key, url } = schema.parse(req.body);

    await pool.execute('INSERT INTO uploads (user_id, s3_key, url) VALUES (?, ?, ?)', [
      req.user.id,
      key,
      url,
    ]);

    return res.json(ok({}));
  } catch (error) {
    if (error instanceof z.ZodError) {
      return fail(res, 'validation_error', 400);
    }
    console.error('Confirm error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// GET /api/files/list
router.get('/list', async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 50, 100);
    const cursor = req.query.cursor;

    const prefix = `u/${req.user.id}/`;

    const command = new ListObjectsV2Command({
      Bucket: BUCKET,
      Prefix: prefix,
      MaxKeys: limit,
      StartAfter: cursor,
    });

    const response = await s3Client.send(command);

    const files = (response.Contents || []).map((obj) => ({
      key: obj.Key,
      size: obj.Size,
      lastModified: obj.LastModified,
    }));

    const meta = {};
    if (response.IsTruncated && files.length > 0) {
      meta.nextCursor = files[files.length - 1].key;
    }

    return res.json(ok(files, meta));
  } catch (error) {
    console.error('List files error:', error);
    return fail(res, 'internal_error', 500);
  }
});

export default router;