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

// Comment schema (supports replies via parent_comment_id)
const commentSchema = z.object({
  content: z.string().min(1).max(1000),
  parent_comment_id: z.string().length(12).optional(),
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

// Fetch repost snapshots for all repost rows in batch
async function getRepostSnapshotMap(rows) {
  const pairs = rows
    .filter(r => r.repost_of)
    .map(r => [r.repost_of, r.user_id]);
  if (pairs.length === 0) return {};

  // Build OR predicate to support MySQL without tuple IN
  const where = pairs.map(() => '(original_post_id = ? AND reposted_by_user_id = ?)').join(' OR ');
  const params = pairs.flat();

  const [snapRows] = await pool.query(
    `SELECT
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
     FROM post_reposts
     WHERE ${where}`,
    params
  );

  const map = {};
  for (const s of snapRows) {
    const key = `${s.original_post_id}:${s.reposted_by_user_id}`;
    map[key] = s;
  }
  return map;
}

// Hydrate posts with author info and user interaction flags
// Enhancements: when a row is a repost (repost_of is not null), embed:
//   - original_post: { author, content/media, counts }
//   - repost_author: { name, username, avatarUrl }
// and set top-level author to the original author (for UI to show original author on card)
async function hydratePosts(rows, meId) {
  if (!rows || rows.length === 0) return [];

  const userIds = rows.map(r => r.user_id);
  const authorMap = await getAuthorMap(userIds);
  const snapshotMap = await getRepostSnapshotMap(rows);

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

  return rows.map(r => {
    const baseCounts = {
      likes: r.likes_count || 0,
      comments: r.comments_count || 0,
      shares: r.shares_count || 0,
      bookmarks: r.bookmarks_count || 0,
      reposts: r.reposts_count || 0,
    };

    const me = {
      liked: isInJsonArray(r.liked_by, meId),
      bookmarked: isInJsonArray(r.bookmarked_by, meId),
      shared: isInJsonArray(r.shared_by, meId),
      reposted: isInJsonArray(r.reposted_by, meId),
    };

    const isRepost = !!r.repost_of;
    const reposterInfo = authorMap[r.user_id] || { name: 'User', username: null, avatarUrl: null };

    if (!isRepost) {
      // Normal post
      return {
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

        // Author info (original poster)
        author: reposterInfo,

        // Interaction counts for this row
        counts: baseCounts,

        // User interaction flags
        me,

        // Interaction lists (for detailed views)
        interactions: {
          liked_by: safeParseJson(r.liked_by),
          shared_by: safeParseJson(r.shared_by),
          bookmarked_by: safeParseJson(r.bookmarked_by),
          reposted_by: safeParseJson(r.reposted_by),
        }
      };
    }

    // Repost row: use snapshot to hydrate original and reposter header
    const snap = snapshotMap[`${r.repost_of}:${r.user_id}`];

    let original_post = null;
    let repost_author = reposterInfo;
    let author = reposterInfo; // default, will be overridden by snapshot original author

    if (snap) {
      let origImageUrls = null;
      if (snap.original_image_urls) {
        try {
          origImageUrls = Array.isArray(snap.original_image_urls)
            ? snap.original_image_urls
            : JSON.parse(snap.original_image_urls);
        } catch (_) {
          origImageUrls = null;
        }
      }

      original_post = {
        content: snap.original_content || null,
        post_type: snap.original_post_type || null,
        image_url: snap.original_image_url || null,
        image_urls: origImageUrls,
        video_url: snap.original_video_url || null,
        counts: {
          likes: Number(snap.original_likes_count || 0),
          comments: Number(snap.original_comments_count || 0),
          shares: Number(snap.original_shares_count || 0),
          reposts: Number(snap.original_reposts_count || 0),
          bookmarks: Number(snap.original_bookmarks_count || 0),
        },
        author: {
          name: snap.original_author_name || 'User',
          username: snap.original_author_username || null,
          avatarUrl: snap.original_author_avatar_url || null,
        },
      };

      repost_author = {
        name: snap.reposter_name || 'User',
        username: snap.reposter_username || null,
        avatarUrl: snap.reposter_avatar_url || null,
      };

      // Top-level author should be original author for the UI card header
      author = original_post.author;
    }

    return {
      id: r.id,
      user_id: r.user_id,
      post_type: r.post_type,
      content: r.content, // usually null for repost row
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
      created_at: r.created_at, // time of repost
      updated_at: r.updated_at,

      // Author of the original (for the main card)
      author,

      // Provide repost author explicitly for UI header
      repost_author,

      // Embed full original snapshot so the client can render without extra calls
      original_post,

      // Use row counts as backup; client prefers original_post.counts if present
      counts: baseCounts,

      me,

      interactions: {
        liked_by: safeParseJson(r.liked_by),
        shared_by: safeParseJson(r.shared_by),
        bookmarked_by: safeParseJson(r.bookmarked_by),
        reposted_by: safeParseJson(r.reposted_by),
      }
    };
  });
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

    const posts = await hydratePosts(rows, req.user.id);
    return res.json(ok({ posts, limit, offset }));
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

// Comments - List (top-level + replies)
router.get('/:postId/comments', async (req, res) => {
  try {
    const { postId } = req.params;

    const [topRows] = await pool.query(
      'SELECT * FROM post_comments WHERE post_id = ? ORDER BY created_at ASC',
      [postId]
    );
    const [replyRows] = await pool.query(
      'SELECT * FROM post_comment_replies WHERE post_id = ? ORDER BY created_at ASC',
      [postId]
    );

    const userIds = [
      ...new Set([
        ...topRows.map(r => r.user_id),
        ...replyRows.map(r => r.user_id),
      ]),
    ];
    const authorMap = await getAuthorMap(userIds);

    const top = topRows.map(r => ({
      ...r,
      parent_comment_id: null,
      author: authorMap[r.user_id] || { name: 'User', username: null, avatarUrl: null },
      liked_by: r.liked_by ? JSON.parse(r.liked_by) : [],
      me: { liked: isInJsonArray(r.liked_by, req.user.id) },
    }));

    const replies = replyRows.map(r => ({
      ...r,
      parent_comment_id: r.parent_reply_id || r.comment_id,
      author: authorMap[r.user_id] || { name: 'User', username: null, avatarUrl: null },
      liked_by: r.liked_by ? JSON.parse(r.liked_by) : [],
      me: { liked: isInJsonArray(r.liked_by, req.user.id) },
    }));

    const comments = [...top, ...replies];
    return res.json(ok({ comments }));
  } catch (error) {
    console.error('List comments error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Comments - Create (top-level or reply)
router.post('/:postId/comments', async (req, res) => {
  try {
    const { postId } = req.params;
    const data = commentSchema.parse(req.body || {});

    // Validate post exists
    const [p] = await pool.query('SELECT id FROM posts WHERE id = ? LIMIT 1', [postId]);
    if (p.length === 0) return fail(res, 'post_not_found', 404);

    const commentId = generateId();

    // If no parent => top-level comment
    if (!data.parent_comment_id) {
      await pool.query(
        'INSERT INTO post_comments (id, post_id, user_id, content) VALUES (?, ?, ?, ?)',
        [commentId, postId, req.user.id, data.content]
      );

      await pool.query(
        'UPDATE posts SET comments_count = comments_count + 1 WHERE id = ?',
        [postId]
      );

      return res.json(ok({ id: commentId }));
    }

    // Otherwise it's a reply; figure out whether replying to a top-level comment or another reply
    const parentId = data.parent_comment_id;

    // Try parent as top-level comment
    const [parentTop] = await pool.query(
      'SELECT id FROM post_comments WHERE id = ? AND post_id = ? LIMIT 1',
      [parentId, postId]
    );

    let rootCommentId = null;
    let parentReplyId = null;

    if (parentTop.length > 0) {
      rootCommentId = parentId;
      parentReplyId = null;
    } else {
      // Try parent as a reply
      const [parentReply] = await pool.query(
        'SELECT id, comment_id FROM post_comment_replies WHERE id = ? AND post_id = ? LIMIT 1',
        [parentId, postId]
      );
      if (parentReply.length === 0) {
        return fail(res, 'parent_comment_not_found', 404);
      }
      rootCommentId = parentReply[0].comment_id;
      parentReplyId = parentId;
    }

    await pool.query(
      'INSERT INTO post_comment_replies (id, post_id, comment_id, parent_reply_id, user_id, content) VALUES (?, ?, ?, ?, ?, ?)',
      [commentId, postId, rootCommentId, parentReplyId, req.user.id, data.content]
    );

    await pool.query(
      'UPDATE posts SET comments_count = comments_count + 1 WHERE id = ?',
      [postId]
    );

    return res.json(ok({ id: commentId }));
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Create comment error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Comments - Like (supports comment or reply)
router.post('/:postId/comments/:commentId/like', async (req, res) => {
  try {
    const { postId, commentId } = req.params;

    // Try top-level comment
    let [rows] = await pool.query(
      'SELECT liked_by FROM post_comments WHERE id = ? AND post_id = ? LIMIT 1',
      [commentId, postId]
    );

    if (rows.length > 0) {
      const newLikedBy = addToJsonArray(rows[0].liked_by, req.user.id);
      const newCount = getJsonArrayCount(newLikedBy);
      await pool.query(
        'UPDATE post_comments SET liked_by = ?, likes_count = ? WHERE id = ? AND post_id = ?',
        [newLikedBy, newCount, commentId, postId]
      );
      return res.json(ok({}));
    }

    // Try reply
    [rows] = await pool.query(
      'SELECT liked_by FROM post_comment_replies WHERE id = ? AND post_id = ? LIMIT 1',
      [commentId, postId]
    );
    if (rows.length === 0) return fail(res, 'comment_not_found', 404);

    const newLikedBy = addToJsonArray(rows[0].liked_by, req.user.id);
    const newCount = getJsonArrayCount(newLikedBy);
    await pool.query(
      'UPDATE post_comment_replies SET liked_by = ?, likes_count = ? WHERE id = ? AND post_id = ?',
      [newLikedBy, newCount, commentId, postId]
    );

    return res.json(ok({}));
  } catch (error) {
    console.error('Comment like error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Comments - Unlike (supports comment or reply)
router.delete('/:postId/comments/:commentId/like', async (req, res) => {
  try {
    const { postId, commentId } = req.params;

    // Try top-level comment
    let [rows] = await pool.query(
      'SELECT liked_by FROM post_comments WHERE id = ? AND post_id = ? LIMIT 1',
      [commentId, postId]
    );

    if (rows.length > 0) {
      const newLikedBy = removeFromJsonArray(rows[0].liked_by, req.user.id);
      const newCount = getJsonArrayCount(newLikedBy);
      await pool.query(
        'UPDATE post_comments SET liked_by = ?, likes_count = ? WHERE id = ? AND post_id = ?',
        [newLikedBy, newCount, commentId, postId]
      );
      return res.json(ok({}));
    }

    // Try reply
    [rows] = await pool.query(
      'SELECT liked_by FROM post_comment_replies WHERE id = ? AND post_id = ? LIMIT 1',
      [commentId, postId]
    );
    if (rows.length === 0) return fail(res, 'comment_not_found', 404);

    const newLikedBy = removeFromJsonArray(rows[0].liked_by, req.user.id);
    const newCount = getJsonArrayCount(newLikedBy);
    await pool.query(
      'UPDATE post_comment_replies SET liked_by = ?, likes_count = ? WHERE id = ? AND post_id = ?',
      [newLikedBy, newCount, commentId, postId]
    );

    return res.json(ok({}));
  } catch (error) {
    console.error('Comment unlike error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Comments - Delete (supports comment or reply)
router.delete('/:postId/comments/:commentId', async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const { postId, commentId } = req.params;

    // Check if it's a top-level comment
    let [rows] = await conn.query(
      'SELECT user_id FROM post_comments WHERE id = ? AND post_id = ? LIMIT 1',
      [commentId, postId]
    );

    if (rows.length > 0) {
      if (rows[0].user_id !== req.user.id) {
        conn.release();
        return fail(res, 'forbidden', 403);
      }

      // Count all replies under this top-level comment
      const [cntRows] = await conn.query(
        'SELECT COUNT(*) AS c FROM post_comment_replies WHERE post_id = ? AND comment_id = ?',
        [postId, commentId]
      );
      const totalToDecrement = 1 + Number(cntRows[0].c || 0);

      await conn.beginTransaction();

      // Delete top-level comment (replies will cascade)
      await conn.query(
        'DELETE FROM post_comments WHERE id = ? AND post_id = ?',
        [commentId, postId]
      );

      await conn.query(
        'UPDATE posts SET comments_count = GREATEST(comments_count - ?, 0) WHERE id = ?',
        [totalToDecrement, postId]
      );

      await conn.commit();
      conn.release();
      return res.json(ok({ deleted: totalToDecrement }));
    }

    // Otherwise, it may be a reply
    const [replyRows] = await conn.query(
      'SELECT user_id, comment_id FROM post_comment_replies WHERE id = ? AND post_id = ? LIMIT 1',
      [commentId, postId]
    );
    if (replyRows.length === 0) {
      conn.release();
      return fail(res, 'comment_not_found', 404);
    }
    if (replyRows[0].user_id !== req.user.id) {
      conn.release();
      return fail(res, 'forbidden', 403);
    }

    // Gather subtree of replies using BFS
    let queue = [commentId];
    const toDelete = new Set(queue);

    while (queue.length > 0) {
      const placeholders = queue.map(() => '?').join(',');
      const [children] = await conn.query(
        `SELECT id FROM post_comment_replies 
         WHERE post_id = ? AND parent_reply_id IN (${placeholders})`,
        [postId, ...queue]
      );
      queue = [];
      for (const row of children) {
        if (!toDelete.has(row.id)) {
          toDelete.add(row.id);
          queue.push(row.id);
        }
      }
    }

    const ids = Array.from(toDelete);
    await conn.beginTransaction();

    // Delete the reply subtree
    if (ids.length > 0) {
      const placeholders = ids.map(() => '?').join(',');
      await conn.query(
        `DELETE FROM post_comment_replies WHERE id IN (${placeholders}) AND post_id = ?`,
        [...ids, postId]
      );
    }

    await conn.query(
      'UPDATE posts SET comments_count = GREATEST(comments_count - ?, 0) WHERE id = ?',
      [ids.length, postId]
    );

    await conn.commit();
    conn.release();
    return res.json(ok({ deleted: ids.length }));
  } catch (error) {
    try { await conn.rollback(); } catch (_) {}
    conn.release();
    console.error('Delete comment error:', error);
    return fail(res, 'internal_error', 500);
  }
});

export default router;