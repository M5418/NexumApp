import express from 'express';
import { z } from 'zod';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';
import { generateId } from '../utils/id-generator.js';

const router = express.Router();

const createImageStorySchema = z.object({
  media_type: z.literal('image'),
  media_url: z.string().url(),
  thumbnail_url: z.string().url().optional(),
  audio_url: z.string().url().optional(),
  audio_title: z.string().max(200).optional(),
  privacy: z.enum(['public', 'followers', 'close_friends']).default('public'),
});

const createVideoStorySchema = z.object({
  media_type: z.literal('video'),
  media_url: z.string().url(),
  thumbnail_url: z.string().url().optional(),
  privacy: z.enum(['public', 'followers', 'close_friends']).default('public'),
});

const createTextStorySchema = z.object({
  media_type: z.literal('text'),
  text_content: z.string().min(1).max(500),
  background_color: z.string().regex(/^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/).optional(),
  privacy: z.enum(['public', 'followers', 'close_friends']).default('public'),
});

const createStorySchema = z.union([
  createImageStorySchema,
  createVideoStorySchema,
  createTextStorySchema,
]);

const batchCreateSchema = z.object({
  items: z.array(createStorySchema).min(1).max(10),
});

function parseJsonArray(x) {
  try {
    if (!x) return [];
    const v = typeof x === 'string' ? JSON.parse(x) : x;
    return Array.isArray(v) ? v : [];
  } catch {
    return [];
  }
}
function uniqueAdd(arr, id) {
  const s = new Set(arr || []);
  s.add(id);
  return Array.from(s);
}
function uniqueRemove(arr, id) {
  const s = new Set(arr || []);
  s.delete(id);
  return Array.from(s);
}
function normalizePair(a, b) { return a < b ? [a, b] : [b, a]; }

async function findExistingConversation(a, b) {
  const [userA, userB] = normalizePair(a, b);
  const [existing] = await pool.execute(
    'SELECT id FROM conversations WHERE user_a_id = ? AND user_b_id = ? LIMIT 1',
    [userA, userB]
  );
  return existing.length > 0 ? existing[0].id : null;
}
async function areConnected(a, b) {
  const [rows] = await pool.execute(
    'SELECT 1 FROM connections WHERE (from_user_id = ? AND to_user_id = ?) OR (from_user_id = ? AND to_user_id = ?) LIMIT 1',
    [a, b, b, a]
  );
  return rows.length > 0;
}
async function createConversation(a, b) {
  const [userA, userB] = normalizePair(a, b);
  const id = generateId();
  await pool.execute(
    'INSERT INTO conversations (id, user_a_id, user_b_id, created_at, updated_at) VALUES (?, ?, ?, NOW(), NOW())',
    [id, userA, userB]
  );
  return id;
}

async function getUserMap(userIds) {
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
      username: r.username ? `@${r.username}` : '@user',
      avatarUrl: r.profile_photo_url || null,
    };
  }
  return map;
}

async function canViewStory(ownerId, viewerId, privacy) {
  if (ownerId === viewerId) return true;
  if (privacy === 'public') return true;
  if (privacy === 'followers') {
    // treat connections as followers; check either direction
    const [rows] = await pool.execute(
      'SELECT 1 FROM connections WHERE (from_user_id = ? AND to_user_id = ?) OR (from_user_id = ? AND to_user_id = ?) LIMIT 1',
      [viewerId, ownerId, ownerId, viewerId]
    );
    return rows.length > 0;
  }
  if (privacy === 'close_friends') {
    // Not implemented yet; default to owner-only
    return false;
  }
  return false;
}

// POST /api/stories
router.post('/', async (req, res) => {
  try {
    const body = createStorySchema.parse(req.body || {});
    const id = generateId();
    const userId = req.user.id;

    const expiresAtSql = 'DATE_ADD(NOW(), INTERVAL 24 HOUR)';

    if (body.media_type === 'text') {
      await pool.execute(
        `INSERT INTO stories (id, user_id, media_type, text_content, background_color, privacy, created_at, expires_at)
         VALUES (?, ?, 'text', ?, ?, ?, NOW(), ${expiresAtSql})`,
        [id, userId, body.text_content, body.background_color || null, body.privacy]
      );
    } else if (body.media_type === 'image') {
      await pool.execute(
        `INSERT INTO stories (id, user_id, media_type, media_url, thumbnail_url, audio_url, audio_title, privacy, created_at, expires_at)
         VALUES (?, ?, 'image', ?, ?, ?, ?, ?, NOW(), ${expiresAtSql})`,
        [id, userId, body.media_url, body.thumbnail_url || null, body.audio_url || null, body.audio_title || null, body.privacy]
      );
    } else {
      await pool.execute(
        `INSERT INTO stories (id, user_id, media_type, media_url, thumbnail_url, privacy, created_at, expires_at)
         VALUES (?, ?, 'video', ?, ?, ?, NOW(), ${expiresAtSql})`,
        [id, userId, body.media_url, body.thumbnail_url || null, body.privacy]
      );
    }

    const [rows] = await pool.execute('SELECT * FROM stories WHERE id = ? LIMIT 1', [id]);
    const uMap = await getUserMap([userId]);
    const story = rows[0];
    return res.json(ok({ story: {
      id: story.id,
      user_id: story.user_id,
      author: uMap[userId] || { name: 'User', username: '@user', avatarUrl: null },
      media_type: story.media_type,
      media_url: story.media_url,
      text_content: story.text_content,
      background_color: story.background_color,
      audio_url: story.audio_url,
      audio_title: story.audio_title,
      thumbnail_url: story.thumbnail_url,
      privacy: story.privacy,
      created_at: story.created_at,
      expires_at: story.expires_at,
      viewers_count: story.viewers_count,
      likes_count: Number(story.likes_count || 0),
      comments_count: Number(story.comments_count || 0),
      liked: false,
    }}));

  } catch (err) {
    if (err instanceof z.ZodError) return fail(res, 'validation_error', 400, err.errors);
    console.error('Create story error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// POST /api/stories/batch
router.post('/batch', async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const { items } = batchCreateSchema.parse(req.body || {});
    const userId = req.user.id;
    const expiresSql = 'DATE_ADD(NOW(), INTERVAL 24 HOUR)';

    await conn.beginTransaction();
    const created = [];
    for (const it of items) {
      const id = generateId();
      if (it.media_type === 'text') {
        await conn.execute(
          `INSERT INTO stories (id, user_id, media_type, text_content, background_color, privacy, created_at, expires_at)
           VALUES (?, ?, 'text', ?, ?, ?, NOW(), ${expiresSql})`,
          [id, userId, it.text_content, it.background_color || null, it.privacy]
        );
      } else if (it.media_type === 'image') {
        await conn.execute(
          `INSERT INTO stories (id, user_id, media_type, media_url, thumbnail_url, audio_url, audio_title, privacy, created_at, expires_at)
           VALUES (?, ?, 'image', ?, ?, ?, ?, ?, NOW(), ${expiresSql})`,
          [id, userId, it.media_url, it.thumbnail_url || null, it.audio_url || null, it.audio_title || null, it.privacy]
        );
      } else {
        await conn.execute(
          `INSERT INTO stories (id, user_id, media_type, media_url, thumbnail_url, privacy, created_at, expires_at)
           VALUES (?, ?, 'video', ?, ?, ?, NOW(), ${expiresSql})`,
          [id, userId, it.media_url, it.thumbnail_url || null, it.privacy]
        );
      }
      created.push(id);
    }
    await conn.commit();

    const [rows] = await pool.query('SELECT * FROM stories WHERE id IN (?)', [created]);
    return res.json(ok({ stories: rows }));
  } catch (err) {
    try { await conn.rollback(); } catch (_) {}
    if (err instanceof z.ZodError) return fail(res, 'validation_error', 400, err.errors);
    console.error('Batch create stories error:', err);
    return fail(res, 'internal_error', 500);
  } finally {
    conn.release();
  }
});

// GET /api/stories/rings
router.get('/rings', async (req, res) => {
  try {
    const meId = req.user.id;

    const [agg] = await pool.query(
      `SELECT s.user_id,
              MAX(s.created_at) AS last_story_at,
              SUM(CASE WHEN v.viewer_id IS NULL THEN 1 ELSE 0 END) AS unseen_count,
              COUNT(*) AS story_count
         FROM stories s
    LEFT JOIN story_mutes m
           ON m.muter_id = ? AND m.target_user_id = s.user_id
    LEFT JOIN story_views v
           ON v.story_id = s.id AND v.viewer_id = ?
        WHERE s.expires_at > NOW()
          AND m.muter_id IS NULL
     GROUP BY s.user_id
     ORDER BY (unseen_count > 0) DESC, last_story_at DESC`,
      [meId, meId]
    );

    const userIds = agg.map(r => r.user_id);
    const uMap = await getUserMap(userIds);

    // Fetch one thumbnail per user (prefer thumbnail_url then media_url for non-text)
    const thumbByUser = {};
    for (const uid of userIds) {
      const [row] = await pool.execute(
        `SELECT thumbnail_url, media_url, media_type
           FROM stories
          WHERE user_id = ? AND expires_at > NOW()
       ORDER BY created_at DESC
          LIMIT 1`,
        [uid]
      );
      if (row.length > 0) {
        const r = row[0];
        thumbByUser[uid] = r.thumbnail_url || (r.media_type !== 'text' ? r.media_url : null);
      } else {
        thumbByUser[uid] = null;
      }
    }

    const rings = agg.map(r => ({
      user_id: r.user_id,
      name: uMap[r.user_id]?.name || 'User',
      username: uMap[r.user_id]?.username || '@user',
      avatarUrl: uMap[r.user_id]?.avatarUrl || null,
      has_unseen: Number(r.unseen_count || 0) > 0,
      last_story_at: r.last_story_at,
      thumbnail_url: thumbByUser[r.user_id] || uMap[r.user_id]?.avatarUrl || null,
      story_count: Number(r.story_count || 0),
    }));

    return res.json(ok({ rings }));
  } catch (err) {
    console.error('List story rings error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// GET /api/stories/:userId
router.get('/:userId', async (req, res) => {
  try {
    const meId = req.user.id;
    const { userId } = req.params;

    const [userRows] = await pool.execute('SELECT id FROM users WHERE id = ? LIMIT 1', [userId]);
    if (userRows.length === 0) return fail(res, 'user_not_found', 404);

    // Fetch active stories
    const [rows] = await pool.execute(
      `SELECT s.*,
              (SELECT 1 FROM story_views v WHERE v.story_id = s.id AND v.viewer_id = ? LIMIT 1) AS has_viewed
         FROM stories s
        WHERE s.user_id = ? AND s.expires_at > NOW()
     ORDER BY s.created_at ASC`,
      [meId, userId]
    );

    if (rows.length === 0) {
      // No active stories; still return user info
      const uMap = await getUserMap([userId]);
      return res.json(ok({
        user: { id: userId, ...(uMap[userId] || { name: 'User', username: '@user', avatarUrl: null }) },
        items: [],
      }));
    }

    // Enforce privacy per story - if any story is restricted, ensure viewer can access
    const anyInaccessible = [];
    for (const s of rows) {
      const allowed = await canViewStory(s.user_id, meId, s.privacy);
      if (!allowed) anyInaccessible.push(s.id);
    }
    if (anyInaccessible.length === rows.length) return fail(res, 'forbidden', 403);

    const uMap = await getUserMap([userId]);
    const items = rows
      .filter(s => !anyInaccessible.includes(s.id))
      .map(s => {
        const likedBy = parseJsonArray(s.liked_by);
        return {
          id: s.id,
          media_type: s.media_type,
          media_url: s.media_url,
          text_content: s.text_content,
          background_color: s.background_color,
          audio_url: s.audio_url,
          audio_title: s.audio_title,
          thumbnail_url: s.thumbnail_url,
          created_at: s.created_at,
          expires_at: s.expires_at,
          viewed: !!s.has_viewed,
          viewers_count: Number(s.viewers_count || 0),
          likes_count: Number(s.likes_count || 0),
          comments_count: Number(s.comments_count || 0),
          liked: likedBy.includes(meId),
        };
      });

    return res.json(ok({
      user: { id: userId, ...(uMap[userId] || { name: 'User', username: '@user', avatarUrl: null }) },
      items,
    }));


  } catch (err) {
    console.error('Get user stories error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// POST /api/stories/:storyId/view
router.post('/:storyId/view', async (req, res) => {
  try {
    const meId = req.user.id;
    const { storyId } = req.params;

    const [rows] = await pool.execute('SELECT * FROM stories WHERE id = ? LIMIT 1', [storyId]);
    if (rows.length === 0) return fail(res, 'not_found', 404);

    // ensure viewer can view per privacy
    const s = rows[0];
    const allowed = await canViewStory(s.user_id, meId, s.privacy);
    if (!allowed) return fail(res, 'forbidden', 403);

    // Insert ignore view
    const [r] = await pool.execute('INSERT IGNORE INTO story_views (story_id, viewer_id) VALUES (?, ?)', [storyId, meId]);
    if (r.affectedRows && r.affectedRows > 0) {
      await pool.execute('UPDATE stories SET viewers_count = viewers_count + 1 WHERE id = ?', [storyId]);
    }

    return res.json(ok({}));
  } catch (err) {
    console.error('Mark story viewed error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// POST /api/stories/:storyId/like
router.post('/:storyId/like', async (req, res) => {
  try {
    const meId = req.user.id;
    const { storyId } = req.params;

    const [rows] = await pool.execute('SELECT * FROM stories WHERE id = ? LIMIT 1', [storyId]);
    if (rows.length === 0) return fail(res, 'not_found', 404);
    const s = rows[0];

    const allowed = await canViewStory(s.user_id, meId, s.privacy);
    if (!allowed) return fail(res, 'forbidden', 403);

    const likedBy = parseJsonArray(s.liked_by);
    let liked;
    let newLikedBy;
    let newCount;

    if (likedBy.includes(meId)) {
      newLikedBy = uniqueRemove(likedBy, meId);
      liked = false;
    } else {
      newLikedBy = uniqueAdd(likedBy, meId);
      liked = true;
    }
    newCount = newLikedBy.length;

    await pool.execute(
      'UPDATE stories SET liked_by = ?, likes_count = ? WHERE id = ?',
      [JSON.stringify(newLikedBy), newCount, storyId]
    );

    return res.json(ok({ liked, likes_count: newCount }));
  } catch (err) {
    console.error('Toggle like error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// POST /api/stories/:storyId/reply
router.post('/:storyId/reply', async (req, res) => {
  try {
    const meId = req.user.id;
    const { storyId } = req.params;
    const { text } = req.body || {};
    if (!text || typeof text !== 'string') return fail(res, 'text_required', 400);

    const [rows] = await pool.execute('SELECT * FROM stories WHERE id = ? LIMIT 1', [storyId]);
    if (rows.length === 0) return fail(res, 'not_found', 404);
    const s = rows[0];

    // Privacy check
    const canView = await canViewStory(s.user_id, meId, s.privacy);
    if (!canView) return fail(res, 'forbidden', 403);

    // Relationship gating: allow if conversation exists OR they are connected
    let conversationId = await findExistingConversation(meId, s.user_id);
    if (!conversationId) {
      const connected = await areConnected(meId, s.user_id);
      if (!connected) {
        return fail(res, 'cannot_comment_no_relationship', 403);
      }
      conversationId = await createConversation(meId, s.user_id);
    }

    const receiverId = s.user_id === meId ? meId : s.user_id;

    // Create a placeholder "Story" message so the actual comment can reply to it (reply bubble in chat)
    const placeholderId = generateId();
    await pool.execute(
      `INSERT INTO chat_messages (id, conversation_id, sender_id, receiver_id, type, text, created_at, updated_at)
       VALUES (?, ?, ?, ?, 'text', ?, NOW(), NOW())`,
      [placeholderId, conversationId, meId, receiverId, 'Story']
    );

    // Insert the actual reply, referencing the placeholder
    const msgId = generateId();
    await pool.execute(
      `INSERT INTO chat_messages (id, conversation_id, sender_id, receiver_id, type, text, reply_to_message_id, created_at, updated_at)
       VALUES (?, ?, ?, ?, 'text', ?, ?, NOW(), NOW())`,
      [msgId, conversationId, meId, receiverId, text, placeholderId]
    );

    await pool.execute(
      `UPDATE conversations
          SET last_message_type = 'text', last_message_text = ?, last_message_at = NOW(), updated_at = NOW()
        WHERE id = ?`,
      [text, conversationId]
    );

    // Update story commented_by + comments_count
    const commentedBy = parseJsonArray(s.commented_by);
    const newCommentedBy = uniqueAdd(commentedBy, meId);
    const newCommentsCount = newCommentedBy.length;
    await pool.execute(
      'UPDATE stories SET commented_by = ?, comments_count = ? WHERE id = ?',
      [JSON.stringify(newCommentedBy), newCommentsCount, storyId]
    );

    return res.json(ok({ conversation_id: conversationId }));
  } catch (err) {
    console.error('Reply to story error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// DELETE /api/stories/:storyId
router.delete('/:storyId', async (req, res) => {
  try {
    const meId = req.user.id;
    const { storyId } = req.params;

    const [rows] = await pool.execute('SELECT * FROM stories WHERE id = ? LIMIT 1', [storyId]);
    if (rows.length === 0) return fail(res, 'not_found', 404);
    const s = rows[0];
    if (s.user_id !== meId) return fail(res, 'forbidden', 403);

    await pool.execute('DELETE FROM stories WHERE id = ?', [storyId]);
    await pool.execute('DELETE FROM story_views WHERE story_id = ?', [storyId]);

    return res.json(ok({}));
  } catch (err) {
    console.error('Delete story error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// POST /api/stories/mute/:targetUserId
router.post('/mute/:targetUserId', async (req, res) => {
  try {
    const meId = req.user.id;
    const { targetUserId } = req.params;
    await pool.execute('INSERT IGNORE INTO story_mutes (muter_id, target_user_id) VALUES (?, ?)', [meId, targetUserId]);
    return res.json(ok({}));
  } catch (err) {
    console.error('Mute stories error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// POST /api/stories/unmute/:targetUserId
router.post('/unmute/:targetUserId', async (req, res) => {
  try {
    const meId = req.user.id;
    const { targetUserId } = req.params;
    await pool.execute('DELETE FROM story_mutes WHERE muter_id = ? AND target_user_id = ?', [meId, targetUserId]);
    return res.json(ok({}));
  } catch (err) {
    console.error('Unmute stories error:', err);
    return fail(res, 'internal_error', 500);
  }
});

export default router;
