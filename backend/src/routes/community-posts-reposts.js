// backend/src/routes/community-posts-reposts.js
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
    try {
      const parsed = JSON.parse(value);
      return JSON.stringify(parsed);
    } catch (_) {
      try {
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

// POST /api/communities/:communityId/posts/:postId/repost
router.post('/:communityId/posts/:postId/repost', async (req, res) => {
  const postId = (req.params.postId || '').trim();
  const communityId = (req.params.communityId || '').trim().toLowerCase();
  const userId =
    (req.user && (req.user.id || req.user.user_id)) ||
    req.header('x-user-id') ||
    req.body.user_id;

  if (!postId) return res.status(400).json({ ok: false, error: 'missing_post_id' });
  if (!communityId) return res.status(400).json({ ok: false, error: 'missing_community_id' });
  if (!userId) return res.status(401).json({ ok: false, error: 'unauthorized' });

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    // Original row must exist in this community
    const original = await queryOne(
      conn,
      `SELECT id, user_id, content, post_type, image_url, image_urls, video_url,
              likes_count, comments_count, shares_count, reposts_count, bookmarks_count,
              reposted_by
         FROM community_posts
        WHERE id = ? AND community_id = ?
        LIMIT 1`,
      [postId, communityId]
    );
    if (!original) {
      await conn.rollback();
      return res.status(404).json({ ok: false, error: 'post_not_found' });
    }

    // Prevent duplicate repost by same user (check snapshot)
    const exists = await queryOne(
      conn,
      `SELECT id FROM community_post_reposts
        WHERE original_post_id = ? AND reposted_by_user_id = ?
        LIMIT 1`,
      [original.id, userId]
    );
    if (exists) {
      await conn.rollback();
      return res.status(409).json({ ok: false, error: 'already_reposted' });
    }

    // 1) Create the repost as a new community post row
    const repostPostId = generateId();
    await conn.query(
      `INSERT INTO community_posts (id, community_id, user_id, post_type, content, image_url, image_urls, video_url, repost_of)
       VALUES (?, ?, ?, 'text', NULL, NULL, NULL, NULL, ?)`,
      [repostPostId, communityId, userId, original.id]
    );

    // 2) Snapshot reposter + original author
    const reposter = await getProfileSnapshot(conn, userId);
    const originalAuthor = await getProfileSnapshot(conn, original.user_id);

    const imageUrlsJson = toJsonValue(original.image_urls);

    await conn.query(
      `INSERT INTO community_post_reposts (
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
      `UPDATE community_posts
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
    if (err && (err.code === 'ER_DUP_ENTRY' || err.errno === 1062)) {
      return res.status(409).json({ ok: false, error: 'already_reposted' });
    }
    console.error('POST /:communityId/posts/:postId/repost error:', err);
    return res.status(500).json({ ok: false, error: 'internal_server_error' });
  } finally {
    conn.release();
  }
});

// DELETE /api/communities/:communityId/posts/:postId/repost
router.delete('/:communityId/posts/:postId/repost', async (req, res) => {
  const postId = (req.params.postId || '').trim();
  const communityId = (req.params.communityId || '').trim().toLowerCase();
  const userId =
    (req.user && (req.user.id || req.user.user_id)) ||
    req.header('x-user-id') ||
    req.body.user_id;

  if (!postId) return res.status(400).json({ ok: false, error: 'missing_post_id' });
  if (!communityId) return res.status(400).json({ ok: false, error: 'missing_community_id' });
  if (!userId) return res.status(401).json({ ok: false, error: 'unauthorized' });

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    const original = await queryOne(
      conn,
      `SELECT id, reposted_by FROM community_posts WHERE id = ? AND community_id = ? LIMIT 1`,
      [postId, communityId]
    );
    if (!original) {
      await conn.rollback();
      return res.status(404).json({ ok: false, error: 'post_not_found' });
    }

    // 1) Delete snapshot if present
    await conn.query(
      `DELETE FROM community_post_reposts
        WHERE original_post_id = ? AND reposted_by_user_id = ?
        LIMIT 1`,
      [original.id, userId]
    );

    // 2) Update JSON + counts on original
    const newRepostedBy = removeFromJsonArray(original.reposted_by, userId);
    const newCount = toArray(newRepostedBy).length;

    await conn.query(
      `UPDATE community_posts
          SET reposted_by = ?, reposts_count = ?
        WHERE id = ?`,
      [newRepostedBy, newCount, original.id]
    );

    // 3) Delete the repost post row created by this user (if exists)
    await conn.query(
      `DELETE FROM community_posts
        WHERE user_id = ? AND community_id = ? AND repost_of = ?
        ORDER BY created_at DESC
        LIMIT 1`,
      [userId, communityId, original.id]
    );

    await conn.commit();
    return res.json({ ok: true, data: { removed: true } });
  } catch (err) {
    try { await conn.rollback(); } catch (_) {}
    console.error('DELETE /:communityId/posts/:postId/repost error:', err);
    return res.status(500).json({ ok: false, error: 'internal_server_error' });
  } finally {
    conn.release();
  }
});

export default router;