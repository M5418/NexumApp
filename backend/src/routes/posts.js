import express from 'express';
import { z } from 'zod';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';
import { generateId } from '../utils/id-generator.js';

const router = express.Router();

// Validation
const mediaItemSchema = z.object({
  media_type: z.enum(['image', 'video']),
  upload_id: z.string().length(12).optional(),
  s3_key: z.string().min(1).optional(),
  url: z.string().url().optional(),
  position: z.number().int().min(0).optional(),
});

const createPostSchema = z.object({
  content: z.string().max(4000).optional(),
  media: z.array(mediaItemSchema).max(8).optional(),
  repost_of: z.string().length(12).optional(),
}).refine((d) => !!(d.content || (d.media && d.media.length) || d.repost_of), {
  message: 'post_requires_content_or_media_or_repost',
});

// Helpers
async function getPostMediaMap(postIds) {
  if (postIds.length === 0) return {};
  const placeholders = postIds.map(() => '?').join(',');
  const [rows] = await pool.query(
    `SELECT id, post_id, media_type, upload_id, s3_key, url, position
       FROM post_media
      WHERE post_id IN (${placeholders})
      ORDER BY position ASC, created_at ASC`,
    postIds
  );
  const map = {};
  for (const r of rows) {
    if (!map[r.post_id]) map[r.post_id] = [];
    map[r.post_id].push({
      id: r.id,
      type: r.media_type,
      upload_id: r.upload_id,
      s3_key: r.s3_key,
      url: r.url,
      position: r.position,
    });
  }
  return map;
}

async function getAuthorMap(userIds) {
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

async function hydrateCountsAndFlags(rows, meId) {
  if (!rows || rows.length === 0) return [];
  const postIds = rows.map(r => r.id);
  const placeholders = postIds.map(() => '?').join(',');

  const [likeCounts] = await pool.query(
    `SELECT post_id, COUNT(*) as c FROM post_likes WHERE post_id IN (${placeholders}) GROUP BY post_id`, postIds);
  const [commentCounts] = await pool.query(
    `SELECT post_id, COUNT(*) as c FROM post_comments WHERE post_id IN (${placeholders}) GROUP BY post_id`, postIds);
  const [shareCounts] = await pool.query(
    `SELECT post_id, COUNT(*) as c FROM post_shares WHERE post_id IN (${placeholders}) GROUP BY post_id`, postIds);
  const [bookmarkCounts] = await pool.query(
    `SELECT post_id, COUNT(*) as c FROM post_bookmarks WHERE post_id IN (${placeholders}) GROUP BY post_id`, postIds);
  const [repostCounts] = await pool.query(
    `SELECT repost_of as post_id, COUNT(*) as c FROM posts WHERE repost_of IN (${placeholders}) GROUP BY repost_of`, postIds);

  const userIds = rows.map(r => r.user_id);
  const authorMap = await getAuthorMap(userIds);

  // Get repost author information for posts that are reposts
  const repostRows = rows.filter(r => r.repost_of);
  const repostAuthorMap = {};
  if (repostRows.length > 0) {
    const repostUserIds = repostRows.map(r => r.user_id);
    const repostAuthors = await getAuthorMap(repostUserIds);
    for (const row of repostRows) {
      repostAuthorMap[row.id] = repostAuthors[row.user_id];
    }
  }

  const [likedByMe] = await pool.query(
    `SELECT post_id FROM post_likes WHERE user_id = ? AND post_id IN (${placeholders})`, [meId, ...postIds]);
  const [bookmarkedByMe] = await pool.query(
    `SELECT post_id FROM post_bookmarks WHERE user_id = ? AND post_id IN (${placeholders})`, [meId, ...postIds]);
  const [sharedByMe] = await pool.query(
    `SELECT post_id FROM post_shares WHERE user_id = ? AND post_id IN (${placeholders})`, [meId, ...postIds]);
  const [repostedByMe] = await pool.query(
    `SELECT repost_of as post_id FROM posts WHERE user_id = ? AND repost_of IN (${placeholders})`, [meId, ...postIds]);

  const likeMap = Object.fromEntries(likeCounts.map(r => [r.post_id, r.c]));
  const commentMap = Object.fromEntries(commentCounts.map(r => [r.post_id, r.c]));
  const shareMap = Object.fromEntries(shareCounts.map(r => [r.post_id, r.c]));
  const bookmarkMap = Object.fromEntries(bookmarkCounts.map(r => [r.post_id, r.c]));
  const repostMap = Object.fromEntries(repostCounts.map(r => [r.post_id, r.c]));
  const likedSet = new Set(likedByMe.map(r => r.post_id));
  const bookmarkedSet = new Set(bookmarkedByMe.map(r => r.post_id));
  const sharedSet = new Set(sharedByMe.map(r => r.post_id));
  const repostedSet = new Set(repostedByMe.map(r => r.post_id));

  const mediaMap = await getPostMediaMap(postIds);

  return rows.map(r => ({
    id: r.id,
    user_id: r.user_id,
    content: r.content,
    repost_of: r.repost_of,
    created_at: r.created_at,
    updated_at: r.updated_at,
    media: mediaMap[r.id] || [],
    author: authorMap[r.user_id] || { name: 'User', username: null, avatarUrl: null },
    repost_author: repostAuthorMap[r.id] || null,
    counts: {
      likes: likeMap[r.id] || 0,
      comments: commentMap[r.id] || 0,
      shares: shareMap[r.id] || 0,
      bookmarks: bookmarkMap[r.id] || 0,
      reposts: repostMap[r.id] || 0,
    },
    me: {
      liked: likedSet.has(r.id),
      bookmarked: bookmarkedSet.has(r.id),
      shared: sharedSet.has(r.id),
      reposted: repostedSet.has(r.id),
    }
  }));
}

// Create a post
router.post('/', async (req, res) => {
  try {
    const body = createPostSchema.parse(req.body || {});

    // Validate repost target if provided
    if (body.repost_of) {
      const [rows] = await pool.query('SELECT id FROM posts WHERE id = ? LIMIT 1', [body.repost_of]);
      if (rows.length === 0) return fail(res, 'repost_target_not_found', 404);
    }

    const postId = generateId();
    await pool.query(
      'INSERT INTO posts (id, user_id, content, repost_of) VALUES (?, ?, ?, ?)',
      [postId, req.user.id, body.content || null, body.repost_of || null]
    );

    if (body.media && body.media.length > 0) {
      for (let i = 0; i < body.media.length; i++) {
        const m = body.media[i];
        const mediaId = generateId();
        await pool.query(
          'INSERT INTO post_media (id, post_id, media_type, upload_id, s3_key, url, position) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [mediaId, postId, m.media_type, m.upload_id || null, m.s3_key || null, m.url || null, m.position ?? i]
        );
      }
    }

    // Return hydrated post
    const [rows] = await pool.query('SELECT * FROM posts WHERE id = ?', [postId]);
    const post = (await hydrateCountsAndFlags(rows, req.user.id))[0];
    return res.json(ok({ post }));
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Create post error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Feed: latest posts, optional user_id filter, pagination via limit & offset
router.get('/', async (req, res) => {
  try {
    const limit = Math.max(1, Math.min(50, Number(req.query.limit) || 20));
    const offset = Math.max(0, Number(req.query.offset) || 0);
    const userId = req.query.user_id;

    let rows;
    if (userId) {
      [rows] = await pool.query(
        'SELECT * FROM posts WHERE user_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?',
        [userId, limit, offset]
      );
    } else {
      [rows] = await pool.query(
        'SELECT * FROM posts ORDER BY created_at DESC LIMIT ? OFFSET ?',
        [limit, offset]
      );
    }

    const posts = await hydrateCountsAndFlags(rows, req.user.id);
    return res.json(ok({ posts, limit, offset }));
  } catch (error) {
    console.error('Feed error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Get a single post with counts and flags
router.get('/:postId', async (req, res) => {
  try {
    const { postId } = req.params;
    const [rows] = await pool.query('SELECT * FROM posts WHERE id = ? LIMIT 1', [postId]);
    if (rows.length === 0) return fail(res, 'not_found', 404);

    const post = (await hydrateCountsAndFlags(rows, req.user.id))[0];
    return res.json(ok({ post }));
  } catch (error) {
    console.error('Get post error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Engagement lists for a post (users who liked, bookmarked, shared, reposted)
router.get('/:postId/engagement', async (req, res) => {
  try {
    const { postId } = req.params;
    const [exists] = await pool.query('SELECT id FROM posts WHERE id = ? LIMIT 1', [postId]);
    if (exists.length === 0) return fail(res, 'not_found', 404);

    const [likes] = await pool.query('SELECT user_id FROM post_likes WHERE post_id = ? ORDER BY created_at DESC', [postId]);
    const [bookmarks] = await pool.query('SELECT user_id FROM post_bookmarks WHERE post_id = ? ORDER BY created_at DESC', [postId]);
    const [shares] = await pool.query('SELECT user_id FROM post_shares WHERE post_id = ? ORDER BY created_at DESC', [postId]);
    const [reposts] = await pool.query('SELECT user_id FROM posts WHERE repost_of = ? ORDER BY created_at DESC', [postId]);
    const [commenters] = await pool.query('SELECT DISTINCT user_id FROM post_comments WHERE post_id = ? ORDER BY user_id ASC', [postId]);
    const [commentsCountRows] = await pool.query('SELECT COUNT(*) AS c FROM post_comments WHERE post_id = ?', [postId]);

    return res.json(ok({
      likes: likes.map(r => r.user_id),
      bookmarks: bookmarks.map(r => r.user_id),
      shares: shares.map(r => r.user_id),
      reposts: reposts.map(r => r.user_id),
      commenters: commenters.map(r => r.user_id),
      counts: {
        likes: likes.length,
        bookmarks: bookmarks.length,
        shares: shares.length,
        reposts: reposts.length,
        comments: commentsCountRows[0]?.c ?? 0
      }
    }));
  } catch (error) {
    console.error('Engagement lists error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Comments
const commentSchema = z.object({
  content: z.string().min(1).max(2000),
  parent_comment_id: z.string().length(12).optional(),
});

router.get('/:postId/comments', async (req, res) => {
  try {
    const { postId } = req.params;
    const [rows] = await pool.query(
      'SELECT id, user_id, content, parent_comment_id, created_at, updated_at FROM post_comments WHERE post_id = ? ORDER BY created_at ASC',
      [postId]
    );
    return res.json(ok({ comments: rows }));
  } catch (error) {
    console.error('List comments error:', error);
    return fail(res, 'internal_error', 500);
  }
});

router.post('/:postId/comments', async (req, res) => {
  try {
    const { postId } = req.params;
    const data = commentSchema.parse(req.body || {});

    // Validate parent if provided
    if (data.parent_comment_id) {
      const [pc] = await pool.query('SELECT id FROM post_comments WHERE id = ? AND post_id = ? LIMIT 1', [data.parent_comment_id, postId]);
      if (pc.length === 0) return fail(res, 'parent_comment_not_found', 404);
    }

    const commentId = generateId();
    await pool.query(
      'INSERT INTO post_comments (id, post_id, user_id, content, parent_comment_id) VALUES (?, ?, ?, ?, ?)',
      [commentId, postId, req.user.id, data.content, data.parent_comment_id || null]
    );

    return res.json(ok({ id: commentId }));
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Create comment error:', error);
    return fail(res, 'internal_error', 500);
  }
});

router.delete('/:postId/comments/:commentId', async (req, res) => {
  try {
    const { postId, commentId } = req.params;
    await pool.query('DELETE FROM post_comments WHERE id = ? AND post_id = ? AND user_id = ? LIMIT 1', [commentId, postId, req.user.id]);
    return res.json(ok({}));
  } catch (error) {
    console.error('Delete comment error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Likes
router.post('/:postId/like', async (req, res) => {
  try {
    const { postId } = req.params;
    await pool.query('INSERT IGNORE INTO post_likes (post_id, user_id) VALUES (?, ?)', [postId, req.user.id]);
    return res.json(ok({}));
  } catch (error) {
    console.error('Like error:', error);
    return fail(res, 'internal_error', 500);
  }
});

router.delete('/:postId/like', async (req, res) => {
  try {
    const { postId } = req.params;
    await pool.query('DELETE FROM post_likes WHERE post_id = ? AND user_id = ? LIMIT 1', [postId, req.user.id]);
    return res.json(ok({}));
  } catch (error) {
    console.error('Unlike error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Bookmarks
router.post('/:postId/bookmark', async (req, res) => {
  try {
    const { postId } = req.params;
    await pool.query('INSERT IGNORE INTO post_bookmarks (post_id, user_id) VALUES (?, ?)', [postId, req.user.id]);
    return res.json(ok({}));
  } catch (error) {
    console.error('Bookmark error:', error);
    return fail(res, 'internal_error', 500);
  }
});

router.delete('/:postId/bookmark', async (req, res) => {
  try {
    const { postId } = req.params;
    await pool.query('DELETE FROM post_bookmarks WHERE post_id = ? AND user_id = ? LIMIT 1', [postId, req.user.id]);
    return res.json(ok({}));
  } catch (error) {
    console.error('Unbookmark error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Shares
router.post('/:postId/share', async (req, res) => {
  try {
    const { postId } = req.params;
    await pool.query('INSERT IGNORE INTO post_shares (post_id, user_id) VALUES (?, ?)', [postId, req.user.id]);
    return res.json(ok({}));
  } catch (error) {
    console.error('Share error:', error);
    return fail(res, 'internal_error', 500);
  }
});

router.delete('/:postId/share', async (req, res) => {
  try {
    const { postId } = req.params;
    await pool.query('DELETE FROM post_shares WHERE post_id = ? AND user_id = ? LIMIT 1', [postId, req.user.id]);
    return res.json(ok({}));
  } catch (error) {
    console.error('Unshare error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Repost
router.post('/:postId/repost', async (req, res) => {
  try {
    const { postId } = req.params;
    // Ensure target exists
    const [rows] = await pool.query('SELECT id FROM posts WHERE id = ? LIMIT 1', [postId]);
    if (rows.length === 0) return fail(res, 'not_found', 404);

    const newId = generateId();
    await pool.query('INSERT INTO posts (id, user_id, content, repost_of) VALUES (?, ?, ?, ?)', [newId, req.user.id, null, postId]);

    return res.json(ok({ id: newId }));
  } catch (error) {
    console.error('Repost error:', error);
    return fail(res, 'internal_error', 500);
  }
});

export default router;
