import express from 'express';
import { z } from 'zod';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';
import { generateId } from '../utils/id-generator.js';

const router = express.Router();

// Validation schemas
const createPostSchema = z.object({
  content: z.string().max(4000).optional(),
  post_type: z.enum(['text', 'text_photo', 'text_video']).default('text'),
  image_url: z.string().url().optional(),
  image_urls: z.array(z.string().url()).max(8).optional(),
  video_url: z.string().url().optional(),
  repost_of: z.string().length(12).optional(),
}).refine((d) => !!(d.content || d.image_url || d.image_urls || d.video_url || d.repost_of), {
  message: 'post_requires_content_or_media_or_repost',
});

// Helper functions for JSON array management (accept string or array)
function toArray(value) {
  if (!value || value === 'null' || value === '') return [];
  if (Array.isArray(value)) return value;
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
      console.warn('Failed to parse JSON to array:', value, e);
      return [];
    }
  }
  // Unknown type
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

function isInJsonArray(jsonArray, userId) {
  const arr = toArray(jsonArray);
  return Array.isArray(arr) && arr.includes(userId);
}

function getJsonArrayCount(jsonArray) {
  const arr = toArray(jsonArray);
  return Array.isArray(arr) ? arr.length : 0;
}

// Get author info
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

// Hydrate posts with author info and user interaction flags
async function hydratePosts(rows, meId) {
  if (!rows || rows.length === 0) return [];
  
  const userIds = rows.map(r => r.user_id);
  const authorMap = await getAuthorMap(userIds);

  function safeParseJson(v) {
    if (v == null || v === '' || v === 'null') return null;
    if (Array.isArray(v) || typeof v === 'object') return v;
    if (typeof v === 'string') {
      try {
        return JSON.parse(v);
      } catch (e) {
        console.warn('Failed to parse JSON:', v, e);
        return null;
      }
    }
    return null;
  }

  return rows.map(r => ({
    id: r.id,
    user_id: r.user_id,
    post_type: r.post_type,
    content: r.content,
    image_url: r.image_url,
    image_urls: (() => {
      if (!r.image_urls) return null;
      if (Array.isArray(r.image_urls)) return r.image_urls;
      if (typeof r.image_urls === 'string') {
        try { return JSON.parse(r.image_urls); } catch (_) { return null; }
      }
      return null;
    })(),
    video_url: r.video_url,
    repost_of: r.repost_of,
    created_at: r.created_at,
    updated_at: r.updated_at,
    
    // Author info
    author: authorMap[r.user_id] || { name: 'User', username: null, avatarUrl: null },
    
    // Interaction counts
    counts: {
      likes: r.likes_count || 0,
      comments: r.comments_count || 0,
      shares: r.shares_count || 0,
      bookmarks: r.bookmarks_count || 0,
      reposts: r.reposts_count || 0,
    },
    
    // User interaction flags
    me: {
      liked: isInJsonArray(r.liked_by, meId),
      bookmarked: isInJsonArray(r.bookmarked_by, meId),
      shared: isInJsonArray(r.shared_by, meId),
      reposted: isInJsonArray(r.reposted_by, meId),
    },
    
    // Interaction lists (for detailed views)
    interactions: {
      liked_by: safeParseJson(r.liked_by),
      shared_by: safeParseJson(r.shared_by),
      bookmarked_by: safeParseJson(r.bookmarked_by),
      reposted_by: safeParseJson(r.reposted_by),
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
      `INSERT INTO posts (id, user_id, post_type, content, image_url, image_urls, video_url, repost_of) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        postId, 
        req.user.id, 
        body.post_type,
        body.content || null,
        body.image_url || null,
        body.image_urls ? JSON.stringify(body.image_urls) : null,
        body.video_url || null,
        body.repost_of || null
      ]
    );

    // Return hydrated post
    const [rows] = await pool.query('SELECT * FROM posts WHERE id = ?', [postId]);
    const post = (await hydratePosts(rows, req.user.id))[0];
    return res.json(ok({ post }));
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Create post error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Get feed
router.get('/', async (req, res) => {
  try {
    const limit = Math.max(1, Math.min(50, Number(req.query.limit) || 20));
    const offset = Math.max(0, Number(req.query.offset) || 0);
    const userId = req.query.user_id;

    console.log('📊 Feed request:', { limit, offset, userId, meId: req.user.id });

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

    console.log('📊 Raw posts from DB:', rows.length, rows.map(r => ({ id: r.id, content: r.content?.substring(0, 50) })));

    const posts = await hydratePosts(rows, req.user.id);
    console.log('📊 Hydrated posts:', posts.length, posts.map(p => ({ 
      id: p.id, 
      content: p.content?.substring(0, 50),
      author: p.author?.name,
      counts: p.counts
    })));

    const response = ok({ posts, limit, offset });
    console.log('📊 API Response structure:', {
      ok: response.ok,
      data: {
        posts: response.data.posts?.length,
        limit: response.data.limit,
        offset: response.data.offset
      }
    });

    return res.json(response);
  } catch (error) {
    console.error('Feed error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Get single post
router.get('/:postId', async (req, res) => {
  try {
    const { postId } = req.params;
    const [rows] = await pool.query('SELECT * FROM posts WHERE id = ? LIMIT 1', [postId]);
    if (rows.length === 0) return fail(res, 'not_found', 404);

    const post = (await hydratePosts(rows, req.user.id))[0];
    return res.json(ok({ post }));
  } catch (error) {
    console.error('Get post error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Like/Unlike post
router.post('/:postId/like', async (req, res) => {
  try {
    const { postId } = req.params;
    const [rows] = await pool.query('SELECT liked_by FROM posts WHERE id = ? LIMIT 1', [postId]);
    if (rows.length === 0) return fail(res, 'not_found', 404);

    const newLikedBy = addToJsonArray(rows[0].liked_by, req.user.id);
    const newCount = getJsonArrayCount(newLikedBy);
    
    await pool.query(
      'UPDATE posts SET liked_by = ?, likes_count = ? WHERE id = ?',
      [newLikedBy, newCount, postId]
    );
    
    return res.json(ok({}));
  } catch (error) {
    console.error('Like error:', error);
    return fail(res, 'internal_error', 500);
  }
});

router.delete('/:postId/like', async (req, res) => {
  try {
    const { postId } = req.params;
    const [rows] = await pool.query('SELECT liked_by FROM posts WHERE id = ? LIMIT 1', [postId]);
    if (rows.length === 0) return fail(res, 'not_found', 404);

    const newLikedBy = removeFromJsonArray(rows[0].liked_by, req.user.id);
    const newCount = getJsonArrayCount(newLikedBy);
    
    await pool.query(
      'UPDATE posts SET liked_by = ?, likes_count = ? WHERE id = ?',
      [newLikedBy, newCount, postId]
    );
    
    return res.json(ok({}));
  } catch (error) {
    console.error('Unlike error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Bookmark/Unbookmark post
router.post('/:postId/bookmark', async (req, res) => {
  try {
    const { postId } = req.params;
    const [rows] = await pool.query('SELECT bookmarked_by FROM posts WHERE id = ? LIMIT 1', [postId]);
    if (rows.length === 0) return fail(res, 'not_found', 404);

    const newBookmarkedBy = addToJsonArray(rows[0].bookmarked_by, req.user.id);
    const newCount = getJsonArrayCount(newBookmarkedBy);

    await pool.query(
      'UPDATE posts SET bookmarked_by = ?, bookmarks_count = ? WHERE id = ?',
      [newBookmarkedBy, newCount, postId]
    );

    return res.json(ok({}));
  } catch (error) {
    console.error('Bookmark error:', error);
    return fail(res, 'internal_error', 500);
  }
});

router.delete('/:postId/bookmark', async (req, res) => {
  try {
    const { postId } = req.params;
    const [rows] = await pool.query('SELECT bookmarked_by FROM posts WHERE id = ? LIMIT 1', [postId]);
    if (rows.length === 0) return fail(res, 'not_found', 404);

    const newBookmarkedBy = removeFromJsonArray(rows[0].bookmarked_by, req.user.id);
    const newCount = getJsonArrayCount(newBookmarkedBy);

    await pool.query(
      'UPDATE posts SET bookmarked_by = ?, bookmarks_count = ? WHERE id = ?',
      [newBookmarkedBy, newCount, postId]
    );

    return res.json(ok({}));
  } catch (error) {
    console.error('Unbookmark error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Similar endpoints for share, repost...
// [Additional endpoints would follow the same pattern]

// Comments
router.get('/:postId/comments', async (req, res) => {
  try {
    const { postId } = req.params;
    const [rows] = await pool.query(
      'SELECT * FROM post_comments WHERE post_id = ? ORDER BY created_at ASC',
      [postId]
    );
    
    // Add author info to comments
    const userIds = rows.map(r => r.user_id);
    const authorMap = await getAuthorMap(userIds);
    
    const comments = rows.map(r => ({
      ...r,
      author: authorMap[r.user_id] || { name: 'User', username: null, avatarUrl: null },
      liked_by: r.liked_by ? JSON.parse(r.liked_by) : [],
      me: {
        liked: isInJsonArray(r.liked_by, req.user.id)
      }
    }));
    
    return res.json(ok({ comments }));
  } catch (error) {
    console.error('List comments error:', error);
    return fail(res, 'internal_error', 500);
  }
});

export default router;
