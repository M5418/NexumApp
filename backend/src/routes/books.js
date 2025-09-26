import express from 'express';
import { z } from 'zod';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';
import { generateId } from '../utils/id-generator.js';

const router = express.Router();

// JSON array helpers (same approach as posts-simplified)
function toArray(value) {
  if (!value || value === 'null' || value === '') return [];
  if (Array.isArray(value)) return value;
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  if (typeof value === 'object') {
    try {
      return Array.isArray(value) ? value : [];
    } catch {
      return [];
    }
  }
  return [];
}
function addToJsonArray(jsonArray, userId) {
  const arr = toArray(jsonArray);
  if (!arr.includes(userId)) arr.push(userId);
  return JSON.stringify(arr);
}
function removeFromJsonArray(jsonArray, userId) {
  const arr = toArray(jsonArray);
  const filtered = arr.filter((id) => id !== userId);
  return JSON.stringify(filtered);
}
function getJsonArrayCount(jsonArray) {
  const arr = toArray(jsonArray);
  return Array.isArray(arr) ? arr.length : 0;
}
function isInJsonArray(jsonArray, userId) {
  const arr = toArray(jsonArray);
  return Array.isArray(arr) && arr.includes(userId);
}

// Validation schemas
const createBookSchema = z.object({
  title: z.string().min(1).max(255),
  author: z.string().min(1).max(255).optional(),
  description: z.string().max(5000).optional(),
  coverUrl: z.string().url().optional(),
  pdfUrl: z.string().url().optional(),
  audioUrl: z.string().url().optional(),
  language: z.string().max(32).optional(),
  category: z.string().max(64).optional(),
  tags: z.array(z.string().min(1)).max(25).optional(),
  price: z.number().nonnegative().optional(),
  isPublished: z.boolean().optional().default(false),
  readingMinutes: z.number().int().positive().optional(),
  audioDurationSec: z.number().int().positive().optional(),
});
const updateBookSchema = createBookSchema.partial();
const listQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(50).optional(),
  offset: z.coerce.number().int().min(0).optional(),
  page: z.coerce.number().int().min(1).optional(),
  authorId: z.string().min(1).optional(), // created_by_user_id
  category: z.string().min(1).optional(),
  q: z.string().min(1).optional(),
  isPublished: z.coerce.boolean().optional(),
  mine: z.coerce.boolean().optional(), // my books regardless of publish status
});

// Helpers
async function getCreatorMap(userIds) {
  if (!userIds || userIds.length === 0) return {};
  const unique = [...new Set(userIds)];
  const placeholders = unique.map(() => '?').join(',');
  const [rows] = await pool.query(
    `SELECT user_id, first_name, last_name, username, profile_photo_url
       FROM profiles
      WHERE user_id IN (${placeholders})`,
    unique
  );
  const map = {};
  for (const r of rows) {
    const name = [r.first_name, r.last_name].filter(Boolean).join(' ').trim();
    map[r.user_id] = {
      name: name || r.username || 'User',
      username: r.username || null,
      avatarUrl: r.profile_photo_url || null,
    };
  }
  return map;
}

function safeParseJson(v) {
  if (v == null || v === '' || v === 'null') return null;
  if (Array.isArray(v) || typeof v === 'object') return v;
  if (typeof v === 'string') {
    try { return JSON.parse(v); } catch { return null; }
  }
  return null;
}

function toBookJson(row, creator, meId) {
  const likedBy = toArray(row.liked_by);
  return {
    id: row.id,
    title: row.title,
    author: row.author_name || null,
    description: row.description || null,
    coverUrl: row.cover_url || null,
    pdfUrl: row.pdf_url || null,
    audioUrl: row.audio_url || null,
    language: row.language || null,
    category: row.category || null,
    tags: (() => {
      if (!row.tags) return [];
      try { return Array.isArray(row.tags) ? row.tags : JSON.parse(row.tags); } catch { return []; }
    })(),
    price: row.price != null ? Number(row.price) : null,
    isPublished: !!row.is_published,
    readingMinutes: row.reading_minutes != null ? Number(row.reading_minutes) : null,
    audioDurationSec: row.audio_duration_sec != null ? Number(row.audio_duration_sec) : null,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    counts: {
      likes: Number(row.likes_count || 0),
      favorites: Number(row.favorites_count || 0),
      reads: Number(row.reads_count || 0),
      plays: Number(row.plays_count || 0),
    },
    me: {
      liked: isInJsonArray(row.liked_by, meId),
      favorite: !!row.me_fav,
    },
    interactions: {
      liked_by: likedBy,
    },
    creator: creator || { name: 'User', username: null, avatarUrl: null },
    created_by_user_id: row.created_by_user_id,
  };
}

// Create a book
router.post('/', async (req, res) => {
  try {
    const body = createBookSchema.parse(req.body || {});
    const id = generateId();

    await pool.execute(
      `INSERT INTO books
        (id, created_by_user_id, title, author_name, description, cover_url, pdf_url, audio_url,
         liked_by, likes_count, language, category, tags, price, is_published, reading_minutes, audio_duration_sec)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        req.user.id,
        body.title,
        body.author || null,
        body.description || null,
        body.coverUrl || null,
        body.pdfUrl || null,
        body.audioUrl || null,
        JSON.stringify([]), // liked_by
        0,                  // likes_count
        body.language || null,
        body.category || null,
        body.tags ? JSON.stringify(body.tags) : null,
        body.price ?? null,
        body.isPublished ? 1 : 0,
        body.readingMinutes ?? null,
        body.audioDurationSec ?? null,
      ]
    );

    const [rows] = await pool.query(
      `SELECT b.*,
              EXISTS(SELECT 1 FROM book_favorites f WHERE f.book_id = b.id AND f.user_id = ?) AS me_fav
         FROM books b
        WHERE b.id = ? LIMIT 1`,
      [req.user.id, id]
    );
    const creators = await getCreatorMap(rows.map(r => r.created_by_user_id));
    const b = rows[0];
    const creator = creators[b.created_by_user_id] || null;
    return res.json(ok({ book: toBookJson(b, creator, req.user.id) }));
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Create book error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// List books
router.get('/', async (req, res) => {
  try {
    const q = listQuerySchema.safeParse(req.query || {});
    if (!q.success) return fail(res, 'validation_error', 400);
    const params = q.data;

    const limit = params.limit ?? 20;
    let offset = params.offset ?? 0;
    if (params.page != null && params.page > 1 && params.offset == null) {
      offset = (params.page - 1) * limit;
    }

    const where = [];
    const values = [];

    if (typeof params.isPublished === 'boolean') {
      where.push('b.is_published = ?');
      values.push(params.isPublished ? 1 : 0);
    } else if (!params.mine) {
      where.push('b.is_published = 1');
    }

    if (params.mine) {
      where.push('b.created_by_user_id = ?');
      values.push(req.user.id);
    }

    if (params.authorId) {
      where.push('b.created_by_user_id = ?');
      values.push(params.authorId);
    }

    if (params.category) {
      where.push('b.category = ?');
      values.push(params.category);
    }

    if (params.q) {
      where.push('(b.title LIKE ? OR b.author_name LIKE ? OR b.description LIKE ?)');
      const like = `%${params.q}%`;
      values.push(like, like, like);
    }

    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

    const [rows] = await pool.query(
      `SELECT b.*,
              EXISTS(SELECT 1 FROM book_favorites f WHERE f.book_id = b.id AND f.user_id = ?) AS me_fav
         FROM books b
        ${whereSql}
        ORDER BY b.created_at DESC
        LIMIT ? OFFSET ?`,
      [req.user.id, ...values, limit, offset]
    );

    const creators = await getCreatorMap(rows.map(r => r.created_by_user_id));
    const books = rows.map(r => toBookJson(r, creators[r.created_by_user_id], req.user.id));
    return res.json(ok({ books, limit, offset }));
  } catch (error) {
    console.error('List books error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Get a single book
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const [rows] = await pool.query(
      `SELECT b.*,
              EXISTS(SELECT 1 FROM book_favorites f WHERE f.book_id = b.id AND f.user_id = ?) AS me_fav
         FROM books b
        WHERE b.id = ? LIMIT 1`,
      [req.user.id, id]
    );
    if (rows.length === 0) return fail(res, 'not_found', 404);
    const creators = await getCreatorMap(rows.map(r => r.created_by_user_id));
    const b = rows[0];
    const creator = creators[b.created_by_user_id] || null;
    return res.json(ok({ book: toBookJson(b, creator, req.user.id) }));
  } catch (error) {
    console.error('Get book error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Update a book (owner only)
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const body = updateBookSchema.parse(req.body || {});

    const [rows] = await pool.query('SELECT created_by_user_id FROM books WHERE id = ? LIMIT 1', [id]);
    if (rows.length === 0) return fail(res, 'not_found', 404);
    if (rows[0].created_by_user_id !== req.user.id) return fail(res, 'forbidden', 403);

    const fields = [];
    const values = [];
    const set = (col, val) => { fields.push(`${col} = ?`); values.push(val); };

    if (body.title !== undefined) set('title', body.title);
    if (body.author !== undefined) set('author_name', body.author || null);
    if (body.description !== undefined) set('description', body.description || null);
    if (body.coverUrl !== undefined) set('cover_url', body.coverUrl || null);
    if (body.pdfUrl !== undefined) set('pdf_url', body.pdfUrl || null);
    if (body.audioUrl !== undefined) set('audio_url', body.audioUrl || null);
    if (body.language !== undefined) set('language', body.language || null);
    if (body.category !== undefined) set('category', body.category || null);
    if (body.tags !== undefined) set('tags', body.tags ? JSON.stringify(body.tags) : null);
    if (body.price !== undefined) set('price', body.price ?? null);
    if (body.isPublished !== undefined) set('is_published', body.isPublished ? 1 : 0);
    if (body.readingMinutes !== undefined) set('reading_minutes', body.readingMinutes ?? null);
    if (body.audioDurationSec !== undefined) set('audio_duration_sec', body.audioDurationSec ?? null);

    if (fields.length === 0) return res.json(ok({}));

    await pool.query(`UPDATE books SET ${fields.join(', ')}, updated_at = NOW() WHERE id = ?`, [...values, id]);
    return res.json(ok({}));
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Update book error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Delete a book (owner only)
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const [rows] = await pool.query('SELECT created_by_user_id FROM books WHERE id = ? LIMIT 1', [id]);
    if (rows.length === 0) return fail(res, 'not_found', 404);
    if (rows[0].created_by_user_id !== req.user.id) return fail(res, 'forbidden', 403);

    await pool.query('DELETE FROM books WHERE id = ?', [id]);
    return res.json(ok({}));
  } catch (error) {
    console.error('Delete book error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Like a book
router.post('/:id/like', async (req, res) => {
  try {
    const { id } = req.params;
    const [rows] = await pool.query('SELECT liked_by FROM books WHERE id = ? LIMIT 1', [id]);
    if (rows.length === 0) return fail(res, 'not_found', 404);

    const newLikedBy = addToJsonArray(rows[0].liked_by, req.user.id);
    const newCount = getJsonArrayCount(newLikedBy);

    await pool.query(
      'UPDATE books SET liked_by = ?, likes_count = ? WHERE id = ?',
      [newLikedBy, newCount, id]
    );

    return res.json(ok({}));
  } catch (error) {
    console.error('Like book error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Unlike a book
router.delete('/:id/like', async (req, res) => {
  try {
    const { id } = req.params;
    const [rows] = await pool.query('SELECT liked_by FROM books WHERE id = ? LIMIT 1', [id]);
    if (rows.length === 0) return fail(res, 'not_found', 404);

    const newLikedBy = removeFromJsonArray(rows[0].liked_by, req.user.id);
    const newCount = getJsonArrayCount(newLikedBy);

    await pool.query(
      'UPDATE books SET liked_by = ?, likes_count = ? WHERE id = ?',
      [newLikedBy, newCount, id]
    );

    return res.json(ok({}));
  } catch (error) {
    console.error('Unlike book error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Favorite
router.post('/:id/favorite', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query(
      `INSERT INTO book_favorites (user_id, book_id) VALUES (?, ?)
       ON DUPLICATE KEY UPDATE created_at = created_at`,
      [req.user.id, id]
    );
    await pool.query(
      `UPDATE books b
          SET b.favorites_count = (SELECT COUNT(*) FROM book_favorites f WHERE f.book_id = b.id)
        WHERE b.id = ?`,
      [id]
    );
    return res.json(ok({}));
  } catch (error) {
    console.error('Favorite book error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Unfavorite
router.delete('/:id/favorite', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM book_favorites WHERE user_id = ? AND book_id = ?', [req.user.id, id]);
    await pool.query(
      `UPDATE books b
          SET b.favorites_count = (SELECT COUNT(*) FROM book_favorites f WHERE f.book_id = b.id)
        WHERE b.id = ?`,
      [id]
    );
    return res.json(ok({}));
  } catch (error) {
    console.error('Unfavorite book error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Get my progress
router.get('/:id/progress', async (req, res) => {
  try {
    const { id } = req.params;
    const [rows] = await pool.query(
      `SELECT last_page, total_pages, last_audio_position_sec, audio_duration_sec,
              finished_reading, finished_audio, updated_at
         FROM book_progress
        WHERE user_id = ? AND book_id = ? LIMIT 1`,
      [req.user.id, id]
    );
    return res.json(ok({ progress: rows[0] || null }));
  } catch (error) {
    console.error('Get progress error:', error);
    return fail(res, 'internal_error', 500);
  }
});

const readProgressSchema = z.object({
  page: z.number().int().min(0),
  totalPages: z.number().int().min(1).optional(),
});
router.put('/:id/progress/read', async (req, res) => {
  try {
    const { id } = req.params;
    const body = readProgressSchema.parse(req.body || {});

    const [existing] = await pool.query(
      'SELECT last_page, total_pages FROM book_progress WHERE user_id = ? AND book_id = ? LIMIT 1',
      [req.user.id, id]
    );
    const wasStarted = existing.length > 0 && existing[0].last_page != null && existing[0].last_page > 0;
    const nowStarted = body.page > 0;

    await pool.query(
      `INSERT INTO book_progress (user_id, book_id, last_page, total_pages)
       VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE last_page = VALUES(last_page), total_pages = COALESCE(VALUES(total_pages), total_pages), updated_at = NOW()`,
      [req.user.id, id, body.page, body.totalPages ?? null]
    );

    if (!wasStarted && nowStarted) {
      await pool.query('UPDATE books SET reads_count = reads_count + 1 WHERE id = ?', [id]);
    }

    if (body.totalPages && body.page >= body.totalPages) {
      await pool.query(
        'UPDATE book_progress SET finished_reading = 1 WHERE user_id = ? AND book_id = ?',
        [req.user.id, id]
      );
    }

    return res.json(ok({}));
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Update read progress error:', error);
    return fail(res, 'internal_error', 500);
  }
});

const audioProgressSchema = z.object({
  positionSec: z.number().int().min(0),
  durationSec: z.number().int().min(1).optional(),
});
router.put('/:id/progress/audio', async (req, res) => {
  try {
    const { id } = req.params;
    const body = audioProgressSchema.parse(req.body || {});

    const [existing] = await pool.query(
      'SELECT last_audio_position_sec FROM book_progress WHERE user_id = ? AND book_id = ? LIMIT 1',
      [req.user.id, id]
    );
    const wasStarted = existing.length > 0 && existing[0].last_audio_position_sec != null && existing[0].last_audio_position_sec > 0;
    const nowStarted = body.positionSec > 0;

    await pool.query(
      `INSERT INTO book_progress (user_id, book_id, last_audio_position_sec, audio_duration_sec)
       VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE last_audio_position_sec = VALUES(last_audio_position_sec),
                               audio_duration_sec = COALESCE(VALUES(audio_duration_sec), audio_duration_sec),
                               updated_at = NOW()`,
      [req.user.id, id, body.positionSec, body.durationSec ?? null]
    );

    if (!wasStarted && nowStarted) {
      await pool.query('UPDATE books SET plays_count = plays_count + 1 WHERE id = ?', [id]);
    }

    if (body.durationSec && body.positionSec >= body.durationSec) {
      await pool.query(
        'UPDATE book_progress SET finished_audio = 1 WHERE user_id = ? AND book_id = ?',
        [req.user.id, id]
      );
    }

    return res.json(ok({}));
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Update audio progress error:', error);
    return fail(res, 'internal_error', 500);
  }
});

export default router;