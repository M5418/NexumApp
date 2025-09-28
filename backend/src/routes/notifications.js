// backend/src/routes/notifications.js
import express from 'express';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';

const router = express.Router();

function formatName(row) {
  const first = (row.actor_first_name || '').trim();
  const last = (row.actor_last_name || '').trim();
  const username = (row.actor_username || '').trim();
  if (first && last) return `${first} ${last}`.trim();
  if (first) return first;
  if (last) return last;
  if (username) return username;
  return 'User';
}

function formatUsername(row) {
  const username = (row.actor_username || '').trim();
  return username ? `@${username}` : '@user';
}

function actionTextFor(type, communityId) {
  switch (type) {
    case 'post_created': return 'posted a new post';
    case 'community_post_created': return communityId ? `posted in ${communityId}` : 'posted in community';
    case 'connection_received': return 'connected with you';
    case 'post_liked': return 'liked your post';
    case 'comment_added': return 'commented on your post';
    case 'comment_liked': return 'liked your comment';
    case 'community_post_liked': return 'liked your community post';
    case 'community_comment_added': return 'commented on your community post';
    case 'community_comment_liked': return 'liked your comment in community';
    case 'invitation_received': return 'sent you an invitation';
    case 'invitation_accepted': return 'accepted your invitation';
    case 'post_tagged': return 'tagged you in a post';
    case 'community_post_tagged': return 'tagged you in a community post';
    default: return 'did something';
  }
}

/**
 * List current user's notifications
 * GET /api/notifications?limit=20&offset=0
 */
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;
    const limit = Math.max(1, Math.min(50, Number(req.query.limit) || 20));
    const offset = Math.max(0, Number(req.query.offset) || 0);

    // Force consistent collation in JOIN and WHERE to avoid "Illegal mix of collations"
    const [rows] = await pool.query(
      `SELECT
         n.*,
         ap.first_name AS actor_first_name,
         ap.last_name  AS actor_last_name,
         ap.username   AS actor_username,
         ap.profile_photo_url AS actor_avatar_url
       FROM notifications n
       LEFT JOIN profiles ap
         ON ap.user_id COLLATE utf8mb4_0900_ai_ci = n.actor_id COLLATE utf8mb4_0900_ai_ci
       WHERE n.user_id COLLATE utf8mb4_0900_ai_ci = ?
       ORDER BY n.created_at DESC
       LIMIT ? OFFSET ?`,
      [userId, limit, offset]
    );

    const items = rows.map(r => ({
      id: r.id,
      type: r.type,
      is_read: !!r.is_read,
      created_at: r.created_at,
      actor: {
        id: r.actor_id,
        name: formatName(r),
        username: formatUsername(r),
        avatarUrl: r.actor_avatar_url || null,
      },
      action_text: actionTextFor(r.type, r.community_id),
      preview_text: r.preview_text || null,
      preview_image_url: r.preview_image_url || null,
      navigate: (() => {
        // client can switch on navigate.type
        switch (r.type) {
          case 'post_created':
          case 'post_liked':
          case 'comment_added':
          case 'comment_liked':
          case 'post_tagged':
            return { type: 'post', params: { postId: r.post_id } };

          case 'community_post_created':
          case 'community_post_liked':
          case 'community_comment_added':
          case 'community_comment_liked':
          case 'community_post_tagged':
            return {
              type: 'community_post',
              params: { communityId: r.community_id, postId: r.community_post_id }
            };

          case 'connection_received':
            return { type: 'user_profile', params: { userId: r.other_user_id || r.actor_id } };

          case 'invitation_received':
            return { type: 'invitation', params: { invitationId: r.invitation_id } };

          case 'invitation_accepted':
            return { type: 'conversation', params: { conversationId: r.conversation_id } };

          default:
            return { type: 'none', params: {} };
        }
      })(),
    }));

    return res.json(ok({ notifications: items, limit, offset }));
  } catch (error) {
    console.error('Notifications list error:', error);
    return fail(res, 'internal_error', 500);
  }
});

/**
 * Mark a single notification as read
 * POST /api/notifications/:id/read
 */
router.post('/:id/read', async (req, res) => {
  try {
    const userId = req.user.id;
    const id = (req.params.id || '').trim();
    if (!id) return fail(res, 'invalid_id', 400);

    const [result] = await pool.execute(
      `UPDATE notifications
          SET is_read = 1, read_at = NOW(), updated_at = NOW()
        WHERE id = ? AND user_id = ?
        LIMIT 1`,
      [id, userId]
    );

    if (result.affectedRows === 0) {
      return fail(res, 'not_found', 404);
    }

    return res.json(ok({ id, is_read: true }));
  } catch (error) {
    console.error('Notification mark read error:', error);
    return fail(res, 'internal_error', 500);
  }
});

/**
 * Mark all notifications as read for current user
 * POST /api/notifications/read-all
 */
router.post('/read-all', async (req, res) => {
  try {
    const userId = req.user.id;
    await pool.execute(
      `UPDATE notifications
          SET is_read = 1, read_at = NOW(), updated_at = NOW()
        WHERE user_id = ? AND is_read = 0`,
      [userId]
    );
    return res.json(ok({}));
  } catch (error) {
    console.error('Notification mark all read error:', error);
    return fail(res, 'internal_error', 500);
  }
});

export default router;