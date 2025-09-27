import express from 'express';
import { z } from 'zod';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';
import { generateId } from '../utils/id-generator.js';

const router = express.Router();

// JSON array helpers (consistent with books/posts)
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

const createSchema = z.object({
  title: z.string().min(1).max(255),
  author: z.string().min(1).max(255).optional(),
  description: z.string().max(5000).optional(),
  coverUrl: z.string().url().optional(),
  audioUrl: z.string().url().optional(),
  durationSec: z.number().int().positive().optional(),
  language: z.string().max(32).optional(),
  category: z.string().max(64).optional(),
  tags: z.array(z.string().min(1)).max(25).optional(),
  isPublished: z.boolean().optional().default(false),
});
const updateSchema = createSchema.partial();

const listQuery = z.object({
  page: z.coerce.number().int().min(1).optional(),
  limit: z.coerce.number().int().min(1).max(50).optional(),
  authorId: z.string().min(1).optional(),
  category: z.string().min(1).optional(),
  q: z.string().min(1).optional(),
  isPublished: z.coerce.boolean().optional(),
  mine: z.coerce.boolean().optional(),
});

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

function toPodcastJson(row, creator, meId) {
  return {
    id: row.id,
    title: row.title,
    author: row.author_name || null,
    description: row.description || null,
    coverUrl: row.cover_url || null,
    audioUrl: row.audio_url || null,
    durationSec: row.duration_sec != null ? Number(row.duration_sec) : null,
    language: row.language || null,
    category: row.category || null,
    tags: (() => {
      if (!row.tags) return [];
      try { return Array.isArray(row.tags) ? row.tags : JSON.parse(row.tags); } catch { return []; }
    })(),
    isPublished: !!row.is_published,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    counts: {
      likes: Number(row.likes_count || 0),
      favorites: Number(row.favorites_count || 0),
      plays: Number(row.plays_count || 0),
    },
    me: {
      liked: isInJsonArray(row.liked_by, meId),
      favorite: !!row.me_fav,
    },
    creator: creator || { name: 'User', username: null, avatarUrl: null },
    created_by_user_id: row.created_by_user_id,
  };
}

// Create podcast
router.post('/', async (req, res) => {
  try {
    const body = createSchema.parse(req.body || {});
    const id = generateId();
    await pool.execute(
      `INSERT INTO podcasts
        (id, created_by_user_id, title, author_name, description, cover_url, audio_url, duration_sec,
         liked_by, likes_count, language, category, tags, is_published, plays_count)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)`,
      [
        id,
        req.user.id,
        body.title,
        body.author || null,
        body.description || null,
        body.coverUrl || null,
        body.audioUrl || null,
        body.durationSec ?? null,
        JSON.stringify([]),
        0,
        body.language || null,
        body.category || null,
        body.tags ? JSON.stringify(body.tags) : null,
        body.isPublished ? 1 : 0,
      ]
    );

    const [rows] = await pool.query(
      `SELECT p.*,
              EXISTS(SELECT 1 FROM podcast_favorites f WHERE f.podcast_id = p.id AND f.user_id = ?) AS me_fav
         FROM podcasts p
        WHERE p.id = ? LIMIT 1`,
      [req.user.id, id]
    );
    const creators = await getCreatorMap(rows.map(r => r.created_by_user_id));
    const r = rows[0];
    return res.json(ok({ podcast: toPodcastJson(r, creators[r.created_by_user_id], req.user.id) }));
  } catch (err) {
    if (err instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Create podcast error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// List podcasts
router.get('/', async (req, res) => {
  try {
    const q = listQuery.safeParse(req.query || {});
    if (!q.success) return fail(res, 'validation_error', 400);
    const params = q.data;

    const limit = params.limit ?? 20;
    let offset = 0;
    if (params.page && params.page > 1) offset = (params.page - 1) * limit;

    const where = [];
    const values = [];

    if (typeof params.isPublished === 'boolean') {
      where.push('p.is_published = ?');
      values.push(params.isPublished ? 1 : 0);
    } else if (!params.mine) {
      where.push('p.is_published = 1');
    }

    if (params.mine) {
      where.push('p.created_by_user_id = ?');
      values.push(req.user.id);
    }
    if (params.authorId) {
      where.push('p.created_by_user_id = ?');
      values.push(params.authorId);
    }
    if (params.category) {
      where.push('p.category = ?');
      values.push(params.category);
    }
    if (params.q) {
      where.push('(p.title LIKE ? OR p.author_name LIKE ? OR p.description LIKE ?)');
      const like = `%${params.q}%`;
      values.push(like, like, like);
    }

    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const [rows] = await pool.query(
      `SELECT p.*,
              EXISTS(SELECT 1 FROM podcast_favorites f WHERE f.podcast_id = p.id AND f.user_id = ?) AS me_fav
         FROM podcasts p
        ${whereSql}
        ORDER BY p.created_at DESC
        LIMIT ? OFFSET ?`,
      [req.user.id, ...values, limit, offset]
    );

    const creators = await getCreatorMap(rows.map(r => r.created_by_user_id));
    const podcasts = rows.map(r => toPodcastJson(r, creators[r.created_by_user_id], req.user.id));
    return res.json(ok({ podcasts, limit, offset }));
  } catch (err) {
    console.error('List podcasts error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Categories with counts
router.get('/categories/list', async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT category, COUNT(*) AS cnt
         FROM podcasts
        WHERE is_published = 1 AND category IS NOT NULL AND category <> ''
     GROUP BY category
     ORDER BY cnt DESC, category ASC`
    );
    const categories = rows.map(r => ({ category: r.category, count: Number(r.cnt || 0) }));
    return res.json(ok({ categories }));
  } catch (err) {
    console.error('Categories list error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// List my favorites
router.get('/favorites/list/mine', async (req, res) => {
  try {
    const me = req.user.id;
    const [rows] = await pool.query(
      `SELECT p.*,
              1 AS me_fav
         FROM podcast_favorites f
         JOIN podcasts p ON p.id = f.podcast_id
        WHERE f.user_id = ?
     ORDER BY f.created_at DESC
        LIMIT 200`,
      [me]
    );
    const creators = await getCreatorMap(rows.map(r => r.created_by_user_id));
    const podcasts = rows.map(r => toPodcastJson(r, creators[r.created_by_user_id], me));
    return res.json(ok({ podcasts }));
  } catch (err) {
    console.error('List favorites error:', err);
    return fail(res, 'internal_error', 500);
  }
});

//
// Playlists (ensure these routes appear before '/:id')
//

// List my playlists with item counts
router.get('/playlists', async (req, res) => {
  try {
    const me = req.user.id;
    const [rows] = await pool.query(
      `SELECT p.*, (SELECT COUNT(*) FROM playlist_items i WHERE i.playlist_id = p.id) AS items_count
         FROM playlists p
        WHERE p.user_id = ?
     ORDER BY p.created_at DESC`,
      [me]
    );
    const playlists = rows.map(r => ({
      id: r.id,
      name: r.name,
      isPrivate: !!r.is_private,
      itemsCount: Number(r.items_count || 0),
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    }));
    return res.json(ok({ playlists }));
  } catch (err) {
    console.error('List playlists error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Create playlist
router.post('/playlists', async (req, res) => {
  try {
    const schema = z.object({
      name: z.string().min(1).max(255),
      isPrivate: z.boolean().optional().default(false),
    });
    const body = schema.parse(req.body || {});
    const id = generateId();
    await pool.execute(
      'INSERT INTO playlists (id, user_id, name, is_private) VALUES (?, ?, ?, ?)',
      [id, req.user.id, body.name, body.isPrivate ? 1 : 0]
    );
    return res.json(ok({ playlist: { id, name: body.name, isPrivate: body.isPrivate === true, itemsCount: 0 } }));
  } catch (err) {
    if (err instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Create playlist error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Get playlist + items (owner or public if not private)
router.get('/playlists/:playlistId', async (req, res) => {
  try {
    const { playlistId } = req.params;
    const [rows] = await pool.query('SELECT * FROM playlists WHERE id = ? LIMIT 1', [playlistId]);
    if (rows.length === 0) return fail(res, 'not_found', 404);
    const pl = rows[0];
    const isOwner = pl.user_id === req.user.id;
    if (!isOwner && pl.is_private) return fail(res, 'forbidden', 403);

    const [items] = await pool.query(
      `SELECT p.*
         FROM playlist_items i
         JOIN podcasts p ON p.id = i.podcast_id
        WHERE i.playlist_id = ?
     ORDER BY i.added_at DESC`,
      [playlistId]
    );

    const creators = await getCreatorMap(items.map(r => r.created_by_user_id));
    const podcasts = items.map(r => toPodcastJson(r, creators[r.created_by_user_id], req.user.id));
    const playlist = {
      id: pl.id,
      name: pl.name,
      isPrivate: !!pl.is_private,
      createdAt: pl.created_at,
      updatedAt: pl.updated_at,
      itemsCount: podcasts.length,
    };
    return res.json(ok({ playlist, items: podcasts }));
  } catch (err) {
    console.error('Get playlist error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Update playlist (owner)
router.put('/playlists/:playlistId', async (req, res) => {
  try {
    const { playlistId } = req.params;
    const schema = z.object({
      name: z.string().min(1).max(255).optional(),
      isPrivate: z.boolean().optional(),
    });
    const body = schema.parse(req.body || {});
    const [rows] = await pool.query('SELECT user_id FROM playlists WHERE id = ? LIMIT 1', [playlistId]);
    if (rows.length === 0) return fail(res, 'not_found', 404);
    if (rows[0].user_id !== req.user.id) return fail(res, 'forbidden', 403);

    const fields = [];
    const values = [];
    const set = (c, v) => { fields.push(`${c} = ?`); values.push(v); };
    if (body.name !== undefined) set('name', body.name);
    if (body.isPrivate !== undefined) set('is_private', body.isPrivate ? 1 : 0);
    if (fields.length === 0) return res.json(ok({}));

    await pool.query(`UPDATE playlists SET ${fields.join(', ')}, updated_at = NOW() WHERE id = ?`, [...values, playlistId]);
    return res.json(ok({}));
  } catch (err) {
    if (err instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Update playlist error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Delete playlist (owner)
router.delete('/playlists/:playlistId', async (req, res) => {
  try {
    const { playlistId } = req.params;
    const [rows] = await pool.query('SELECT user_id FROM playlists WHERE id = ? LIMIT 1', [playlistId]);
    if (rows.length === 0) return fail(res, 'not_found', 404);
    if (rows[0].user_id !== req.user.id) return fail(res, 'forbidden', 403);
    await pool.query('DELETE FROM playlists WHERE id = ?', [playlistId]);
    return res.json(ok({}));
  } catch (err) {
    console.error('Delete playlist error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Add item (owner)
router.post('/playlists/:playlistId/items', async (req, res) => {
  try {
    const { playlistId } = req.params;
    const schema = z.object({ podcastId: z.string().min(1) });
    const body = schema.parse(req.body || {});
    const [rows] = await pool.query('SELECT user_id FROM playlists WHERE id = ? LIMIT 1', [playlistId]);
    if (rows.length === 0) return fail(res, 'not_found', 404);
    if (rows[0].user_id !== req.user.id) return fail(res, 'forbidden', 403);

    await pool.query(
      `INSERT INTO playlist_items (playlist_id, podcast_id) VALUES (?, ?)
       ON DUPLICATE KEY UPDATE added_at = added_at`,
      [playlistId, body.podcastId]
    );
    return res.json(ok({}));
  } catch (err) {
    if (err instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Add playlist item error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Remove item (owner)
router.delete('/playlists/:playlistId/items/:podcastId', async (req, res) => {
  try {
    const { playlistId, podcastId } = req.params;
    const [rows] = await pool.query('SELECT user_id FROM playlists WHERE id = ? LIMIT 1', [playlistId]);
    if (rows.length === 0) return fail(res, 'not_found', 404);
    if (rows[0].user_id !== req.user.id) return fail(res, 'forbidden', 403);

    await pool.query('DELETE FROM playlist_items WHERE playlist_id = ? AND podcast_id = ?', [playlistId, podcastId]);
    return res.json(ok({}));
  } catch (err) {
    console.error('Remove playlist item error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// For bottom sheet: list my playlists with contains flag for a podcast
router.get('/playlists/for/:podcastId', async (req, res) => {
  try {
    const me = req.user.id;
    const { podcastId } = req.params;
    const [rows] = await pool.query(
      `SELECT p.*,
              EXISTS(SELECT 1 FROM playlist_items i WHERE i.playlist_id = p.id AND i.podcast_id = ?) AS contains_item,
              (SELECT COUNT(*) FROM playlist_items i2 WHERE i2.playlist_id = p.id) AS items_count
         FROM playlists p
        WHERE p.user_id = ?
     ORDER BY p.created_at DESC`,
      [podcastId, me]
    );
    const playlists = rows.map(r => ({
      id: r.id,
      name: r.name,
      isPrivate: !!r.is_private,
      contains: !!r.contains_item,
      itemsCount: Number(r.items_count || 0),
    }));
    return res.json(ok({ playlists }));
  } catch (err) {
    console.error('List playlists for podcast error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Get single
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const [rows] = await pool.query(
      `SELECT p.*,
              EXISTS(SELECT 1 FROM podcast_favorites f WHERE f.podcast_id = p.id AND f.user_id = ?) AS me_fav
         FROM podcasts p
        WHERE p.id = ? LIMIT 1`,
      [req.user.id, id]
    );
    if (rows.length === 0) return fail(res, 'not_found', 404);
    const creators = await getCreatorMap(rows.map(r => r.created_by_user_id));
    const r = rows[0];
    return res.json(ok({ podcast: toPodcastJson(r, creators[r.created_by_user_id], req.user.id) }));
  } catch (err) {
    console.error('Get podcast error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Update (owner)
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const body = updateSchema.parse(req.body || {});
    const [rows] = await pool.query('SELECT created_by_user_id FROM podcasts WHERE id = ? LIMIT 1', [id]);
    if (rows.length === 0) return fail(res, 'not_found', 404);
    if (rows[0].created_by_user_id !== req.user.id) return fail(res, 'forbidden', 403);

    const fields = [];
    const values = [];
    const set = (col, val) => { fields.push(`${col} = ?`); values.push(val); };

    if (body.title !== undefined) set('title', body.title);
    if (body.author !== undefined) set('author_name', body.author || null);
    if (body.description !== undefined) set('description', body.description || null);
    if (body.coverUrl !== undefined) set('cover_url', body.coverUrl || null);
    if (body.audioUrl !== undefined) set('audio_url', body.audioUrl || null);
    if (body.durationSec !== undefined) set('duration_sec', body.durationSec ?? null);
    if (body.language !== undefined) set('language', body.language || null);
    if (body.category !== undefined) set('category', body.category || null);
    if (body.tags !== undefined) set('tags', body.tags ? JSON.stringify(body.tags) : null);
    if (body.isPublished !== undefined) set('is_published', body.isPublished ? 1 : 0);

    if (fields.length === 0) return res.json(ok({}));
    await pool.query(`UPDATE podcasts SET ${fields.join(', ')}, updated_at = NOW() WHERE id = ?`, [...values, id]);
    return res.json(ok({}));
  } catch (err) {
    if (err instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Update podcast error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Delete (owner)
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const [rows] = await pool.query('SELECT created_by_user_id FROM podcasts WHERE id = ? LIMIT 1', [id]);
    if (rows.length === 0) return fail(res, 'not_found', 404);
    if (rows[0].created_by_user_id !== req.user.id) return fail(res, 'forbidden', 403);
    await pool.query('DELETE FROM podcasts WHERE id = ?', [id]);
    return res.json(ok({}));
  } catch (err) {
    console.error('Delete podcast error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Like / Unlike
router.post('/:id/like', async (req, res) => {
  try {
    const { id } = req.params;
    const [rows] = await pool.query('SELECT liked_by FROM podcasts WHERE id = ? LIMIT 1', [id]);
    if (rows.length === 0) return fail(res, 'not_found', 404);
    const newLikedBy = addToJsonArray(rows[0].liked_by, req.user.id);
    const newCount = getJsonArrayCount(newLikedBy);
    await pool.query('UPDATE podcasts SET liked_by = ?, likes_count = ? WHERE id = ?', [newLikedBy, newCount, id]);
    return res.json(ok({}));
  } catch (err) {
    console.error('Like podcast error:', err);
    return fail(res, 'internal_error', 500);
  }
});
router.delete('/:id/like', async (req, res) => {
  try {
    const { id } = req.params;
    const [rows] = await pool.query('SELECT liked_by FROM podcasts WHERE id = ? LIMIT 1', [id]);
    if (rows.length === 0) return fail(res, 'not_found', 404);
    const newLikedBy = removeFromJsonArray(rows[0].liked_by, req.user.id);
    const newCount = getJsonArrayCount(newLikedBy);
    await pool.query('UPDATE podcasts SET liked_by = ?, likes_count = ? WHERE id = ?', [newLikedBy, newCount, id]);
    return res.json(ok({}));
  } catch (err) {
    console.error('Unlike podcast error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Favorite / Unfavorite
router.post('/:id/favorite', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query(
      `INSERT INTO podcast_favorites (user_id, podcast_id) VALUES (?, ?)
       ON DUPLICATE KEY UPDATE created_at = created_at`,
      [req.user.id, id]
    );
    await pool.query(
      `UPDATE podcasts p
          SET p.favorites_count = (SELECT COUNT(*) FROM podcast_favorites f WHERE f.podcast_id = p.id)
        WHERE p.id = ?`,
      [id]
    );
    return res.json(ok({}));
  } catch (err) {
    console.error('Favorite podcast error:', err);
    return fail(res, 'internal_error', 500);
  }
});
router.delete('/:id/favorite', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM podcast_favorites WHERE user_id = ? AND podcast_id = ?', [req.user.id, id]);
    await pool.query(
      `UPDATE podcasts p
          SET p.favorites_count = (SELECT COUNT(*) FROM podcast_favorites f WHERE f.podcast_id = p.id)
        WHERE p.id = ?`,
      [id]
    );
    return res.json(ok({}));
  } catch (err) {
    console.error('Unfavorite podcast error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Progress: GET
router.get('/:id/progress', async (req, res) => {
  try {
    const { id } = req.params;
    const [rows] = await pool.query(
      `SELECT last_position_sec, duration_sec, finished_audio, updated_at
         FROM podcast_progress
        WHERE user_id = ? AND podcast_id = ? LIMIT 1`,
      [req.user.id, id]
    );
    return res.json(ok({ progress: rows[0] || null }));
  } catch (err) {
    console.error('Get progress error:', err);
    return fail(res, 'internal_error', 500);
  }
});

const audioProgressSchema = z.object({
  positionSec: z.number().int().min(0),
  durationSec: z.number().int().min(1).optional(),
});

// Progress: PUT
router.put('/:id/progress/audio', async (req, res) => {
  try {
    const { id } = req.params;
    const body = audioProgressSchema.parse(req.body || {});

    const [existing] = await pool.query(
      'SELECT last_position_sec FROM podcast_progress WHERE user_id = ? AND podcast_id = ? LIMIT 1',
      [req.user.id, id]
    );
    const wasStarted =
      existing.length > 0 && existing[0].last_position_sec != null && existing[0].last_position_sec > 0;
    const nowStarted = body.positionSec > 0;

    await pool.query(
      `INSERT INTO podcast_progress (user_id, podcast_id, last_position_sec, duration_sec)
       VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE last_position_sec = VALUES(last_position_sec),
                               duration_sec = COALESCE(VALUES(duration_sec), duration_sec),
                               updated_at = NOW()`,
      [req.user.id, id, body.positionSec, body.durationSec ?? null]
    );

    if (!wasStarted && nowStarted) {
      await pool.query('UPDATE podcasts SET plays_count = plays_count + 1 WHERE id = ?', [id]);
    }
    if (body.durationSec && body.positionSec >= body.durationSec) {
      await pool.query(
        'UPDATE podcast_progress SET finished_audio = 1 WHERE user_id = ? AND podcast_id = ?',
        [req.user.id, id]
      );
    }

    return res.json(ok({}));
  } catch (err) {
    if (err instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Update audio progress error:', err);
    return fail(res, 'internal_error', 500);
  }
});

export default router;