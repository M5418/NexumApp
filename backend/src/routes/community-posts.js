// backend/src/routes/community-posts.js
import express from 'express';
import { z } from 'zod';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';
import { generateId } from '../utils/id-generator.js';
import { COMMUNITY_BY_ID } from '../data/communities.js';
import { topicsFromInterests } from '../data/interest-mapping.js';
import { createNotification } from '../utils/notifications.js';

const router = express.Router();

// Validation schemas
const createPostSchema = z.object({
  content: z.string().max(4000).optional(),
  post_type: z.enum(['text', 'text_photo', 'text_video']).default('text'),
  image_url: z.string().url().optional(),
  image_urls: z.array(z.string().url()).max(8).optional(),
  video_url: z.string().url().optional(),
  repost_of: z.string().length(12).optional(),
  tagged_user_ids: z.array(z.string()).max(50).optional(),
}).refine((d) => !!(d.content || d.image_url || d.image_urls || d.video_url || d.repost_of), {
  message: 'post_requires_content_or_media_or_repost',
});

// Comment schema (supports replies via parent_comment_id)
const commentSchema = z.object({
  content: z.string().min(1).max(1000),
  parent_comment_id: z.string().length(12).optional(),
});

// JSON array helpers
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
     FROM community_post_reposts
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

// Hydrate posts with author info and user interaction flags (and repost snapshots if applicable)
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
      // for client hint
      is_repost_author: false,
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

        // Author info (poster)
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

      // Top-level author should be original author for the UI card
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

      author,           // original author (for card)
      repost_author,    // who reposted
      original_post,    // snapshot

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

// Helpers to compute community members (derived from interest_topics)
function parseInterests(jsonVal) {
  if (!jsonVal) return [];
  try {
    const data = typeof jsonVal === 'string' ? JSON.parse(jsonVal) : jsonVal;
    return Array.isArray(data) ? data.filter((x) => typeof x === 'string') : [];
  } catch {
    return [];
  }
}

async function getCommunityMemberUserIds(communityId) {
  const community = COMMUNITY_BY_ID[communityId];
  if (!community) return [];
  const targetTopic = community.name;

  const [rows] = await pool.query(
    `SELECT u.id, p.interest_domains
       FROM users u
  LEFT JOIN profiles p ON p.user_id = u.id`
  );

  const members = [];
  for (const r of rows) {
    const ints = parseInterests(r.interest_domains);
    const topics = topicsFromInterests(ints);
    if (topics.includes(targetTopic)) {
      members.push(r.id);
    }
  }
  return members;
}

// Helper: ensure community exists by slug id
function ensureCommunityOr404(communityId) {
  const id = (communityId || '').trim().toLowerCase();
  const community = COMMUNITY_BY_ID[id];
  return community ? id : null;
}

// Create a post in a community
router.post('/:communityId/posts', async (req, res) => {
  try {
    const communityId = ensureCommunityOr404(req.params.communityId);
    if (!communityId) return fail(res, 'community_not_found', 404);

    const body = createPostSchema.parse(req.body || {});

    // Validate repost target if provided
    if (body.repost_of) {
      const [rows] = await pool.query(
        'SELECT id FROM community_posts WHERE id = ? AND community_id = ? LIMIT 1',
        [body.repost_of, communityId]
      );
      if (rows.length === 0) return fail(res, 'repost_target_not_found', 404);
    }

    const postId = generateId();
    await pool.query(
      `INSERT INTO community_posts (id, community_id, user_id, post_type, content, image_url, image_urls, video_url, repost_of, tagged_user_ids) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        postId,
        communityId,
        req.user.id,
        body.post_type,
        body.content || null,
        body.image_url || null,
        body.image_urls ? JSON.stringify(body.image_urls) : null,
        body.video_url || null,
        body.repost_of || null,
        body.tagged_user_ids ? JSON.stringify(body.tagged_user_ids) : null,
      ]
    );

    // Prepare preview data for notifications
    const previewImageUrl =
      body.image_url ||
      (Array.isArray(body.image_urls) && body.image_urls.length > 0 ? body.image_urls[0] : null);
    const previewText = body.content ? String(body.content).slice(0, 140) : null;

    // Notify tagged users (community_post_tagged)
    const notified = new Set();
    if (Array.isArray(body.tagged_user_ids) && body.tagged_user_ids.length > 0) {
      const uniqueTags = [...new Set(body.tagged_user_ids)].filter((u) => u && u !== req.user.id);
      for (const taggedId of uniqueTags) {
        try {
          await createNotification({
            user_id: taggedId,
            actor_id: req.user.id,
            type: 'community_post_tagged',
            community_id: communityId,
            community_post_id: postId,
            preview_text: previewText,
            preview_image_url: previewImageUrl,
          });
          notified.add(taggedId);
        } catch (e) {
          console.error('notify community_post_tagged error:', e);
        }
      }
    }

    // Notify community members (community_post_created), excluding author and tagged
    try {
      const members = await getCommunityMemberUserIds(communityId);
      for (const uid of members) {
        if (!uid || uid === req.user.id || notified.has(uid)) continue;
        try {
          await createNotification({
            user_id: uid,
            actor_id: req.user.id,
            type: 'community_post_created',
            community_id: communityId,
            community_post_id: postId,
            preview_text: previewText,
            preview_image_url: previewImageUrl,
          });
        } catch (e) {
          console.error('notify community_post_created error:', e);
        }
      }
    } catch (e) {
      console.error('load members for community_post_created error:', e);
    }

    // Return hydrated post
    const [rows] = await pool.query('SELECT * FROM community_posts WHERE id = ? LIMIT 1', [postId]);
    const post = (await hydratePosts(rows, req.user.id))[0];
    return res.json(ok({ post }));
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Community create post error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Get community feed (by community)
router.get('/:communityId/posts', async (req, res) => {
  try {
    const communityId = ensureCommunityOr404(req.params.communityId);
    if (!communityId) return fail(res, 'community_not_found', 404);

    const limit = Math.max(1, Math.min(50, Number(req.query.limit) || 20));
    const offset = Math.max(0, Number(req.query.offset) || 0);

    const [rows] = await pool.query(
      'SELECT * FROM community_posts WHERE community_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?',
      [communityId, limit, offset]
    );

    const posts = await hydratePosts(rows, req.user.id);
    return res.json(ok({ posts, limit, offset }));
  } catch (error) {
    console.error('Community feed error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Get single community post
router.get('/:communityId/posts/:postId', async (req, res) => {
    try {
      const communityId = ensureCommunityOr404(req.params.communityId);
      if (!communityId) return fail(res, 'community_not_found', 404);
      const { postId } = req.params;
  
      const [rows] = await pool.query(
        'SELECT * FROM community_posts WHERE id = ? AND community_id = ? LIMIT 1',
        [postId, communityId]
      );
      if (rows.length === 0) return fail(res, 'not_found', 404);
  
      const post = (await hydratePosts(rows, req.user.id))[0];
      return res.json(ok({ post }));
    } catch (error) {
      console.error('Get community post error:', error);
      return fail(res, 'internal_error', 500);
    }
  });

/**
 * Part 2: Interactions + Comments with notifications
 */

// Like/Unlike a community post
router.post('/:communityId/posts/:postId/like', async (req, res) => {
  try {
    const communityId = ensureCommunityOr404(req.params.communityId);
    if (!communityId) return fail(res, 'community_not_found', 404);
    const { postId } = req.params;

    const [rows] = await pool.query(
      'SELECT liked_by, user_id FROM community_posts WHERE id = ? AND community_id = ? LIMIT 1',
      [postId, communityId]
    );
    if (rows.length === 0) return fail(res, 'not_found', 404);

    const newLikedBy = addToJsonArray(rows[0].liked_by, req.user.id);
    const newCount = getJsonArrayCount(newLikedBy);

    await pool.query(
      'UPDATE community_posts SET liked_by = ?, likes_count = ? WHERE id = ?',
      [newLikedBy, newCount, postId]
    );

    // Notify post author (community_post_liked)
    try {
      const authorId = rows[0].user_id;
      if (authorId && authorId !== req.user.id) {
        await createNotification({
          user_id: authorId,
          actor_id: req.user.id,
          type: 'community_post_liked',
          community_id: communityId,
          community_post_id: postId,
        });
      }
    } catch (e) {
      console.error('notify community_post_liked error:', e);
    }

    return res.json(ok({}));
  } catch (error) {
    console.error('Community like error:', error);
    return fail(res, 'internal_error', 500);
  }
});

router.delete('/:communityId/posts/:postId/like', async (req, res) => {
  try {
    const communityId = ensureCommunityOr404(req.params.communityId);
    if (!communityId) return fail(res, 'community_not_found', 404);
    const { postId } = req.params;

    const [rows] = await pool.query(
      'SELECT liked_by FROM community_posts WHERE id = ? AND community_id = ? LIMIT 1',
      [postId, communityId]
    );
    if (rows.length === 0) return fail(res, 'not_found', 404);

    const newLikedBy = removeFromJsonArray(rows[0].liked_by, req.user.id);
    const newCount = getJsonArrayCount(newLikedBy);

    await pool.query(
      'UPDATE community_posts SET liked_by = ?, likes_count = ? WHERE id = ?',
      [newLikedBy, newCount, postId]
    );

    return res.json(ok({}));
  } catch (error) {
    console.error('Community unlike error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Bookmark/Unbookmark a community post
router.post('/:communityId/posts/:postId/bookmark', async (req, res) => {
  try {
    const communityId = ensureCommunityOr404(req.params.communityId);
    if (!communityId) return fail(res, 'community_not_found', 404);
    const { postId } = req.params;

    const [rows] = await pool.query(
      'SELECT bookmarked_by FROM community_posts WHERE id = ? AND community_id = ? LIMIT 1',
      [postId, communityId]
    );
    if (rows.length === 0) return fail(res, 'not_found', 404);

    const newBookmarkedBy = addToJsonArray(rows[0].bookmarked_by, req.user.id);
    const newCount = getJsonArrayCount(newBookmarkedBy);

    await pool.query(
      'UPDATE community_posts SET bookmarked_by = ?, bookmarks_count = ? WHERE id = ?',
      [newBookmarkedBy, newCount, postId]
    );

    return res.json(ok({}));
  } catch (error) {
    console.error('Community bookmark error:', error);
    return fail(res, 'internal_error', 500);
  }
});

router.delete('/:communityId/posts/:postId/bookmark', async (req, res) => {
  try {
    const communityId = ensureCommunityOr404(req.params.communityId);
    if (!communityId) return fail(res, 'community_not_found', 404);
    const { postId } = req.params;

    const [rows] = await pool.query(
      'SELECT bookmarked_by FROM community_posts WHERE id = ? AND community_id = ? LIMIT 1',
      [postId, communityId]
    );
    if (rows.length === 0) return fail(res, 'not_found', 404);

    const newBookmarkedBy = removeFromJsonArray(rows[0].bookmarked_by, req.user.id);
    const newCount = getJsonArrayCount(newBookmarkedBy);

    await pool.query(
      'UPDATE community_posts SET bookmarked_by = ?, bookmarks_count = ? WHERE id = ?',
      [newBookmarkedBy, newCount, postId]
    );

    return res.json(ok({}));
  } catch (error) {
    console.error('Community unbookmark error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Comments - List (top-level + replies)
router.get('/:communityId/posts/:postId/comments', async (req, res) => {
  try {
    const communityId = ensureCommunityOr404(req.params.communityId);
    if (!communityId) return fail(res, 'community_not_found', 404);
    const { postId } = req.params;

    // We can list by post_id directly; post existence is implicitly assumed
    const [topRows] = await pool.query(
      'SELECT * FROM community_post_comments WHERE post_id = ? ORDER BY created_at ASC',
      [postId]
    );
    const [replyRows] = await pool.query(
      'SELECT * FROM community_post_comment_replies WHERE post_id = ? ORDER BY created_at ASC',
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
    console.error('Community list comments error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Comments - Create (top-level or reply)
router.post('/:communityId/posts/:postId/comments', async (req, res) => {
  try {
    const communityId = ensureCommunityOr404(req.params.communityId);
    if (!communityId) return fail(res, 'community_not_found', 404);
    const { postId } = req.params;
    const data = commentSchema.parse(req.body || {});

    // Validate post exists + get author
    const [p] = await pool.query(
      'SELECT id, user_id FROM community_posts WHERE id = ? AND community_id = ? LIMIT 1',
      [postId, communityId]
    );
    if (p.length === 0) return fail(res, 'post_not_found', 404);

    const commentId = generateId();

    // If no parent => top-level comment
    if (!data.parent_comment_id) {
      await pool.query(
        'INSERT INTO community_post_comments (id, post_id, user_id, content) VALUES (?, ?, ?, ?)',
        [commentId, postId, req.user.id, data.content]
      );

      await pool.query(
        'UPDATE community_posts SET comments_count = comments_count + 1 WHERE id = ? AND community_id = ?',
        [postId, communityId]
      );

      // Notify post author (community_comment_added)
      try {
        const postAuthorId = p[0].user_id;
        if (postAuthorId && postAuthorId !== req.user.id) {
          await createNotification({
            user_id: postAuthorId,
            actor_id: req.user.id,
            type: 'community_comment_added',
            community_id: communityId,
            community_post_id: postId,
            community_comment_id: commentId,
          });
        }
      } catch (e) {
        console.error('notify community_comment_added (post author) error:', e);
      }

      return res.json(ok({ id: commentId }));
    }

    // Otherwise it's a reply; figure out whether replying to a top-level comment or another reply
    const parentId = data.parent_comment_id;

    // Try parent as top-level comment (need user_id to notify)
    const [parentTop] = await pool.query(
      'SELECT id, user_id FROM community_post_comments WHERE id = ? AND post_id = ? LIMIT 1',
      [parentId, postId]
    );

    let rootCommentId = null;
    let parentReplyId = null;
    let notifyUserId = null;

    if (parentTop.length > 0) {
      rootCommentId = parentId;
      parentReplyId = null;
      notifyUserId = parentTop[0].user_id;
    } else {
      // Try parent as a reply (need user_id to notify)
      const [parentReply] = await pool.query(
        'SELECT id, comment_id, user_id FROM community_post_comment_replies WHERE id = ? AND post_id = ? LIMIT 1',
        [parentId, postId]
      );
      if (parentReply.length === 0) {
        return fail(res, 'parent_comment_not_found', 404);
      }
      rootCommentId = parentReply[0].comment_id;
      parentReplyId = parentId;
      notifyUserId = parentReply[0].user_id;
    }

    await pool.query(
      'INSERT INTO community_post_comment_replies (id, post_id, comment_id, parent_reply_id, user_id, content) VALUES (?, ?, ?, ?, ?, ?)',
      [commentId, postId, rootCommentId, parentReplyId, req.user.id, data.content]
    );

    await pool.query(
      'UPDATE community_posts SET comments_count = comments_count + 1 WHERE id = ? AND community_id = ?',
      [postId, communityId]
    );

    // Notify the parent comment/reply author (community_comment_added)
    try {
      if (notifyUserId && notifyUserId !== req.user.id) {
        await createNotification({
          user_id: notifyUserId,
          actor_id: req.user.id,
          type: 'community_comment_added',
          community_id: communityId,
          community_post_id: postId,
          community_comment_id: commentId,
        });
      }
    } catch (e) {
      console.error('notify community_comment_added (parent) error:', e);
    }

    return res.json(ok({ id: commentId }));
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Community create comment error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Comments - Like (supports comment or reply)
router.post('/:communityId/posts/:postId/comments/:commentId/like', async (req, res) => {
  try {
    const communityId = ensureCommunityOr404(req.params.communityId);
    if (!communityId) return fail(res, 'community_not_found', 404);
    const { postId, commentId } = req.params;

    // Try top-level comment
    let [rows] = await pool.query(
      'SELECT liked_by, user_id FROM community_post_comments WHERE id = ? AND post_id = ? LIMIT 1',
      [commentId, postId]
    );

    if (rows.length > 0) {
      const newLikedBy = addToJsonArray(rows[0].liked_by, req.user.id);
      const newCount = getJsonArrayCount(newLikedBy);
      await pool.query(
        'UPDATE community_post_comments SET liked_by = ?, likes_count = ? WHERE id = ? AND post_id = ?',
        [newLikedBy, newCount, commentId, postId]
      );

      // Notify comment author (community_comment_liked)
      try {
        const commentAuthorId = rows[0].user_id;
        if (commentAuthorId && commentAuthorId !== req.user.id) {
          await createNotification({
            user_id: commentAuthorId,
            actor_id: req.user.id,
            type: 'community_comment_liked',
            community_id: communityId,
            community_post_id: postId,
            community_comment_id: commentId,
          });
        }
      } catch (e) {
        console.error('notify community_comment_liked (top-level) error:', e);
      }

      return res.json(ok({}));
    }

    // Try reply
    [rows] = await pool.query(
      'SELECT liked_by, user_id FROM community_post_comment_replies WHERE id = ? AND post_id = ? LIMIT 1',
      [commentId, postId]
    );
    if (rows.length === 0) return fail(res, 'comment_not_found', 404);

    const newLikedBy = addToJsonArray(rows[0].liked_by, req.user.id);
    const newCount = getJsonArrayCount(newLikedBy);
    await pool.query(
      'UPDATE community_post_comment_replies SET liked_by = ?, likes_count = ? WHERE id = ? AND post_id = ?',
      [newLikedBy, newCount, commentId, postId]
    );

    // Notify reply author (community_comment_liked)
    try {
      const replyAuthorId = rows[0].user_id;
      if (replyAuthorId && replyAuthorId !== req.user.id) {
        await createNotification({
          user_id: replyAuthorId,
          actor_id: req.user.id,
          type: 'community_comment_liked',
          community_id: communityId,
          community_post_id: postId,
          community_comment_id: commentId,
        });
      }
    } catch (e) {
      console.error('notify community_comment_liked (reply) error:', e);
    }

    return res.json(ok({}));
  } catch (error) {
    console.error('Community comment like error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Comments - Unlike (supports comment or reply)
router.delete('/:communityId/posts/:postId/comments/:commentId/like', async (req, res) => {
  try {
    const communityId = ensureCommunityOr404(req.params.communityId);
    if (!communityId) return fail(res, 'community_not_found', 404);
    const { postId, commentId } = req.params;

    // Try top-level comment
    let [rows] = await pool.query(
      'SELECT liked_by FROM community_post_comments WHERE id = ? AND post_id = ? LIMIT 1',
      [commentId, postId]
    );

    if (rows.length > 0) {
      const newLikedBy = removeFromJsonArray(rows[0].liked_by, req.user.id);
      const newCount = getJsonArrayCount(newLikedBy);
      await pool.query(
        'UPDATE community_post_comments SET liked_by = ?, likes_count = ? WHERE id = ? AND post_id = ?',
        [newLikedBy, newCount, commentId, postId]
      );
      return res.json(ok({}));
    }

    // Try reply
    [rows] = await pool.query(
      'SELECT liked_by FROM community_post_comment_replies WHERE id = ? AND post_id = ? LIMIT 1',
      [commentId, postId]
    );
    if (rows.length === 0) return fail(res, 'comment_not_found', 404);

    const newLikedBy = removeFromJsonArray(rows[0].liked_by, req.user.id);
    const newCount = getJsonArrayCount(newLikedBy);
    await pool.query(
      'UPDATE community_post_comment_replies SET liked_by = ?, likes_count = ? WHERE id = ? AND post_id = ?',
      [newLikedBy, newCount, commentId, postId]
    );

    return res.json(ok({}));
  } catch (error) {
    console.error('Community comment unlike error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Comments - Delete (supports comment or reply)
router.delete('/:communityId/posts/:postId/comments/:commentId', async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const communityId = ensureCommunityOr404(req.params.communityId);
    if (!communityId) {
      conn.release();
      return fail(res, 'community_not_found', 404);
    }
    const { postId, commentId } = req.params;

    // Check if it's a top-level comment
    let [rows] = await conn.query(
      'SELECT user_id FROM community_post_comments WHERE id = ? AND post_id = ? LIMIT 1',
      [commentId, postId]
    );

    if (rows.length > 0) {
      if (rows[0].user_id !== req.user.id) {
        conn.release();
        return fail(res, 'forbidden', 403);
      }

      // Count all replies under this top-level comment
      const [cntRows] = await conn.query(
        'SELECT COUNT(*) AS c FROM community_post_comment_replies WHERE post_id = ? AND comment_id = ?',
        [postId, commentId]
      );
      const totalToDecrement = 1 + Number(cntRows[0].c || 0);

      await conn.beginTransaction();

      // Delete top-level comment (replies will cascade)
      await conn.query(
        'DELETE FROM community_post_comments WHERE id = ? AND post_id = ?',
        [commentId, postId]
      );

      await conn.query(
        'UPDATE community_posts SET comments_count = GREATEST(comments_count - ?, 0) WHERE id = ? AND community_id = ?',
        [totalToDecrement, postId, communityId]
      );

      await conn.commit();
      conn.release();
      return res.json(ok({ deleted: totalToDecrement }));
    }

    // Otherwise, it may be a reply
    const [replyRows] = await conn.query(
      'SELECT user_id, comment_id FROM community_post_comment_replies WHERE id = ? AND post_id = ? LIMIT 1',
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
        `SELECT id FROM community_post_comment_replies 
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
        `DELETE FROM community_post_comment_replies WHERE id IN (${placeholders}) AND post_id = ?`,
        [...ids, postId]
      );
    }

    await conn.query(
      'UPDATE community_posts SET comments_count = GREATEST(comments_count - ?, 0) WHERE id = ? AND community_id = ?',
      [ids.length, postId, communityId]
    );

    await conn.commit();
    conn.release();
    return res.json(ok({ deleted: ids.length }));
  } catch (error) {
    try { await conn.rollback(); } catch (_) {}
    conn.release();
    console.error('Community delete comment error:', error);
    return fail(res, 'internal_error', 500);
  }
});

export default router;