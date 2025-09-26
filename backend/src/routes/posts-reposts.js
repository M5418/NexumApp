// backend/src/routes/posts-reposts.js
// Repost endpoints that:
// 1) Create a new post row with repost_of (so it appears in feed)
// 2) Snapshot original + reposter data into post_reposts
// 3) Maintain reposts_count and reposted_by JSON on the original
//
// Mount in server.js:
//   import repostsRoutes from './routes/posts-reposts.js';
//   app.use('/api/posts', authMiddleware, repostsRoutes);

import express from 'express';
import pool from '../db/db.js';
import { generateId } from '../utils/id-generator.js';

const router = express.Router();

// Helpers
async function queryOne(conn, sql, params) {
  const [rows] = await conn.query(sql, params);
  return rows && rows.length ? rows[0] : null;
}

function toArray(value) {
  if (!value || value === 'null' || value === '') return [];
  if (Array.isArray(value)) return value;
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch (_) {
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

function toJsonValue(value) {
  if (value == null) return null;
  if (Array.isArray(value)) return JSON.stringify(value);
  if (typeof value === 'string') {
    // Try parse, otherwise keep as-is stringified if it looks like a CSV
    try {
      const parsed = JSON.parse(value);
      return JSON.stringify(parsed);
    } catch (_) {
      try {
        // maybe "['a','b']" single quotes
        const normalized = value.replace(/'/g, '"');
        const parsed2 = JSON.parse(normalized);
        return JSON.stringify(parsed2);
      } catch {
        return JSON.stringify([]);
      }
    }
  }
  if (typeof value === 'object') return JSON.stringify(value);
  return JSON.stringify([]);
}

// Pull display info from profiles to avoid extra joins at render time
async function getProfileSnapshot(conn, userId) {
  const row = await queryOne(
    conn,
    `SELECT first_name, last_name, username, profile_photo_url
       FROM profiles
      WHERE user_id = ?
      LIMIT 1`,
    [userId]
  );

  const name =
    [row?.first_name, row?.last_name].filter(Boolean).join(' ').trim() ||
    row?.username ||
    null;

  return {
    name,
    username: row?.username || null,
    avatar_url: row?.profile_photo_url || null,
  };
}

// POST /api/posts/:postId/repost
// Creates a posts row (repost_of), snapshots into post_reposts,
// bumps original.reposts_count and updates original.reposted_by JSON.
router.post('/:postId/repost', async (req, res) => {
  const postId = (req.params.postId || '').trim();
  const userId =
    (req.user && (req.user.id || req.user.user_id)) ||
    req.header('x-user-id') ||
    req.body.user_id;

  if (!postId) return res.status(400).json({ ok: false, error: 'missing_post_id' });
  if (!userId) return res.status(401).json({ ok: false, error: 'unauthorized' });

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    // Original row must exist
    const original = await queryOne(
      conn,
      `SELECT id, user_id, content, post_type, image_url, image_urls, video_url,
              likes_count, comments_count, shares_count, reposts_count, bookmarks_count,
              reposted_by
         FROM posts
        WHERE id = ?
        LIMIT 1`,
      [postId]
    );
    if (!original) {
      await conn.rollback();
      return res.status(404).json({ ok: false, error: 'post_not_found' });
    }

    // Optional: normalize to root original if you disallow reposting a repost
    // If your posts schema has repost_of, you can detect and replace postId with root id here.

    // Prevent duplicate repost by same user (check post_reposts snapshot)
    const exists = await queryOne(
      conn,
      `SELECT id FROM post_reposts
        WHERE original_post_id = ? AND reposted_by_user_id = ?
        LIMIT 1`,
      [original.id, userId]
    );
    if (exists) {
      await conn.rollback();
      return res.status(409).json({ ok: false, error: 'already_reposted' });
    }

    // 1) Create the repost as a new post row (so it appears in the feed)
    const repostPostId = generateId();
    await conn.query(
      `INSERT INTO posts (id, user_id, post_type, content, image_url, image_urls, video_url, repost_of)
       VALUES (?, ?, 'text', NULL, NULL, NULL, NULL, ?)`,
      [repostPostId, userId, original.id]
    );

    // 2) Snapshot reposter + original author
    const reposter = await getProfileSnapshot(conn, userId);
    const originalAuthor = await getProfileSnapshot(conn, original.user_id);

    const imageUrlsJson = toJsonValue(original.image_urls);

    await conn.query(
      `INSERT INTO post_reposts (
         original_post_id,
         reposted_by_user_id,
         reposter_name,
         reposter_username,
         reposter_avatar_url,
         original_author_id,
         original_author_name,
         original_author_username,
         original_author_avatar_url,
         original_content,
         original_post_type,
         original_image_url,
         original_image_urls,
         original_video_url,
         original_likes_count,
         original_comments_count,
         original_shares_count,
         original_reposts_count,
         original_bookmarks_count
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        original.id,
        userId,
        reposter.name,
        reposter.username,
        reposter.avatar_url,
        original.user_id,
        originalAuthor.name,
        originalAuthor.username,
        originalAuthor.avatar_url,
        original.content || null,
        original.post_type || null,
        original.image_url || null,
        imageUrlsJson,
        original.video_url || null,
        Number(original.likes_count || 0),
        Number(original.comments_count || 0),
        Number(original.shares_count || 0),
        Number(original.reposts_count || 0),
        Number(original.bookmarks_count || 0),
      ]
    );

    // 3) Update original.reposted_by JSON and reposts_count
    const updatedRepostedBy = addToJsonArray(original.reposted_by, userId);
    const newCount = toArray(updatedRepostedBy).length;

    await conn.query(
      `UPDATE posts
          SET reposted_by = ?, reposts_count = ?
        WHERE id = ?`,
      [updatedRepostedBy, newCount, original.id]
    );

    await conn.commit();
    return res.json({
      ok: true,
      data: {
        repost_post_id: repostPostId,
        original_post_id: original.id,
      },
    });
  } catch (err) {
    try { await conn.rollback(); } catch (_) {}
    // Unique constraint on snapshot table
    if (err && (err.code === 'ER_DUP_ENTRY' || err.errno === 1062)) {
      return res.status(409).json({ ok: false, error: 'already_reposted' });
    }
    console.error('POST /:postId/repost error:', err);
    return res.status(500).json({ ok: false, error: 'internal_server_error' });
  } finally {
    conn.release();
  }
});

// DELETE /api/posts/:postId/repost
// Removes snapshot, decrements counts, updates JSON,
// and deletes the repost post row for the current user if it exists.
router.delete('/:postId/repost', async (req, res) => {
  const postId = (req.params.postId || '').trim();
  const userId =
    (req.user && (req.user.id || req.user.user_id)) ||
    req.header('x-user-id') ||
    req.body.user_id;

  if (!postId) return res.status(400).json({ ok: false, error: 'missing_post_id' });
  if (!userId) return res.status(401).json({ ok: false, error: 'unauthorized' });

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    const original = await queryOne(
      conn,
      `SELECT id, reposted_by FROM posts WHERE id = ? LIMIT 1`,
      [postId]
    );
    if (!original) {
      await conn.rollback();
      return res.status(404).json({ ok: false, error: 'post_not_found' });
    }

    // 1) Delete snapshot if present
    await conn.query(
      `DELETE FROM post_reposts
        WHERE original_post_id = ? AND reposted_by_user_id = ?
        LIMIT 1`,
      [original.id, userId]
    );

    // 2) Update JSON + counts on original
    const newRepostedBy = removeFromJsonArray(original.reposted_by, userId);
    const newCount = toArray(newRepostedBy).length;

    await conn.query(
      `UPDATE posts
          SET reposted_by = ?, reposts_count = ?
        WHERE id = ?`,
      [newRepostedBy, newCount, original.id]
    );

    // 3) Delete the repost post row created by this user (if exists)
    await conn.query(
      `DELETE FROM posts
        WHERE user_id = ? AND repost_of = ?
        ORDER BY created_at DESC
        LIMIT 1`,
      [userId, original.id]
    );

    await conn.commit();
    return res.json({ ok: true, data: { removed: true } });
  } catch (err) {
    try { await conn.rollback(); } catch (_) {}
    console.error('DELETE /:postId/repost error:', err);
    return res.status(500).json({ ok: false, error: 'internal_server_error' });
  } finally {
    conn.release();
  }
});

export default router;