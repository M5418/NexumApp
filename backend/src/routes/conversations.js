import express from 'express';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';
import { generateId } from '../utils/id-generator.js';

const router = express.Router();

function normalizePair(a, b) {
  return a < b ? [a, b] : [b, a];
}

// List conversations for current user (respects per-user message hides)
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;

    const [rows] = await pool.execute(
      `SELECT 
         c.*, 
         CASE WHEN c.user_a_id = ? THEN c.user_b_id ELSE c.user_a_id END AS other_user_id,
         p.first_name, p.last_name, p.username, p.profile_photo_url,

         -- unread count for current user (exclude messages hidden by this user)
         (SELECT COUNT(*) FROM chat_messages m 
            WHERE m.conversation_id = c.id 
              AND m.receiver_id = ? 
              AND m.read_at IS NULL
              AND m.id NOT IN (SELECT message_id FROM chat_message_hides WHERE user_id = ?)
         ) AS unread_count,

         -- effective last message fields (excluding messages hidden by this user)
         (SELECT m.sender_id FROM chat_messages m 
            WHERE m.conversation_id = c.id
              AND m.id NOT IN (SELECT message_id FROM chat_message_hides WHERE user_id = ?)
            ORDER BY m.created_at DESC LIMIT 1) AS eff_last_sender_id,

         (SELECT IF(m.read_at IS NULL, 0, 1) FROM chat_messages m 
            WHERE m.conversation_id = c.id
              AND m.id NOT IN (SELECT message_id FROM chat_message_hides WHERE user_id = ?)
            ORDER BY m.created_at DESC LIMIT 1) AS eff_last_read_flag,

         (SELECT m.type FROM chat_messages m 
            WHERE m.conversation_id = c.id
              AND m.id NOT IN (SELECT message_id FROM chat_message_hides WHERE user_id = ?)
            ORDER BY m.created_at DESC LIMIT 1) AS eff_last_message_type,

         (SELECT m.text FROM chat_messages m 
            WHERE m.conversation_id = c.id
              AND m.id NOT IN (SELECT message_id FROM chat_message_hides WHERE user_id = ?)
            ORDER BY m.created_at DESC LIMIT 1) AS eff_last_message_text,

         (SELECT m.created_at FROM chat_messages m 
            WHERE m.conversation_id = c.id
              AND m.id NOT IN (SELECT message_id FROM chat_message_hides WHERE user_id = ?)
            ORDER BY m.created_at DESC LIMIT 1) AS eff_last_message_at

       FROM conversations c
       LEFT JOIN profiles p 
         ON p.user_id = (CASE WHEN c.user_a_id = ? THEN c.user_b_id ELSE c.user_a_id END)
       WHERE (c.user_a_id = ? AND c.user_a_deleted = 0) 
          OR (c.user_b_id = ? AND c.user_b_deleted = 0)
       ORDER BY (eff_last_message_at IS NULL), eff_last_message_at DESC`,
      [
        userId, // other_user_id CASE
        userId, // unread_count receiver_id
        userId, // unread_count hides
        userId, // eff_last_sender_id hides
        userId, // eff_last_read_flag hides
        userId, // eff_last_message_type hides
        userId, // eff_last_message_text hides
        userId, // eff_last_message_at hides
        userId, // LEFT JOIN profiles CASE
        userId, // WHERE user_a
        userId, // WHERE user_b
      ]
    );

    const conversations = rows.map(r => {
      const first = (r.first_name || '').trim();
      const last = (r.last_name || '').trim();
      const combined = `${first} ${last}`.trim();
      const name = combined.length > 0 ? combined : (r.username || 'User');

      // Fallback to conversation columns if the effective ones are null
      const lastType = r.eff_last_message_type || r.last_message_type || null;
      const lastText = r.eff_last_message_text || r.last_message_text || null;
      const lastAt = r.eff_last_message_at || r.last_message_at || null;

      return {
        id: r.id,
        other_user_id: r.other_user_id,
        other_user: {
          name,
          username: r.username ? `@${r.username}` : '@user',
          avatarUrl: r.profile_photo_url || null,
        },
        last_message_type: lastType,
        last_message_text: lastText,
        last_message_at: lastAt,
        unread_count: Number(r.unread_count || 0),
        muted: (r.user_a_id === userId ? !!r.user_a_muted : !!r.user_b_muted),
        last_from_current_user: r.eff_last_sender_id
          ? (r.eff_last_sender_id === userId)
          : null,
        last_read: r.eff_last_read_flag != null
          ? (r.eff_last_read_flag === 1)
          : null,
      };
    });

    return res.json(ok({ conversations }));
  } catch (err) {
    console.error('List conversations error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Create or get existing conversation with another user
router.post('/', async (req, res) => {
  try {
    const userId = req.user.id;
    const { other_user_id } = req.body;
    if (!other_user_id || typeof other_user_id !== 'string') {
      return fail(res, 'other_user_id_required', 400);
    }
    if (other_user_id === userId) {
      return fail(res, 'cannot_chat_self', 400);
    }

    const [a, b] = normalizePair(userId, other_user_id);

    // Find existing
    const [existing] = await pool.execute(
      'SELECT * FROM conversations WHERE user_a_id = ? AND user_b_id = ? LIMIT 1',
      [a, b]
    );

    if (existing.length > 0) {
      const conv = existing[0];
      return res.json(ok({ conversation: { id: conv.id } }));
    }

    const id = generateId();
    await pool.execute(
      'INSERT INTO conversations (id, user_a_id, user_b_id) VALUES (?, ?, ?)',
      [id, a, b]
    );

    return res.json(ok({ conversation: { id } }));
  } catch (err) {
    console.error('Create conversation error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Mark conversation as read for current user
router.post('/:id/mark-read', async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const [rows] = await pool.execute('SELECT * FROM conversations WHERE id = ? LIMIT 1', [id]);
    if (rows.length === 0) return fail(res, 'conversation_not_found', 404);
    const c = rows[0];

    const field = (c.user_a_id === userId) ? 'user_a_last_read_at' : (c.user_b_id === userId) ? 'user_b_last_read_at' : null;
    if (!field) return fail(res, 'not_member_of_conversation', 403);

    await pool.execute(`UPDATE conversations SET ${field} = NOW() WHERE id = ?`, [id]);
    await pool.execute(
      'UPDATE chat_messages SET read_at = NOW() WHERE conversation_id = ? AND receiver_id = ? AND read_at IS NULL',
      [id, userId]
    );

    return res.json(ok({ message: 'marked_read' }));
  } catch (err) {
    console.error('Mark read error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Mute / Unmute
router.post('/:id/mute', async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;
    const [rows] = await pool.execute('SELECT * FROM conversations WHERE id = ? LIMIT 1', [id]);
    if (rows.length === 0) return fail(res, 'conversation_not_found', 404);
    const c = rows[0];

    if (c.user_a_id === userId) {
      await pool.execute('UPDATE conversations SET user_a_muted = 1 WHERE id = ?', [id]);
    } else if (c.user_b_id === userId) {
      await pool.execute('UPDATE conversations SET user_b_muted = 1 WHERE id = ?', [id]);
    } else {
      return fail(res, 'not_member_of_conversation', 403);
    }

    return res.json(ok({ message: 'muted' }));
  } catch (err) {
    console.error('Mute error:', err);
    return fail(res, 'internal_error', 500);
  }
});

router.post('/:id/unmute', async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;
    const [rows] = await pool.execute('SELECT * FROM conversations WHERE id = ? LIMIT 1', [id]);
    if (rows.length === 0) return fail(res, 'conversation_not_found', 404);
    const c = rows[0];

    if (c.user_a_id === userId) {
      await pool.execute('UPDATE conversations SET user_a_muted = 0 WHERE id = ?', [id]);
    } else if (c.user_b_id === userId) {
      await pool.execute('UPDATE conversations SET user_b_muted = 0 WHERE id = ?', [id]);
    } else {
      return fail(res, 'not_member_of_conversation', 403);
    }

    return res.json(ok({ message: 'unmuted' }));
  } catch (err) {
    console.error('Unmute error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Soft delete (hide conversation for current user)
router.delete('/:id', async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;
    const [rows] = await pool.execute('SELECT * FROM conversations WHERE id = ? LIMIT 1', [id]);
    if (rows.length === 0) return fail(res, 'conversation_not_found', 404);
    const c = rows[0];

    if (c.user_a_id === userId) {
      await pool.execute('UPDATE conversations SET user_a_deleted = 1 WHERE id = ?', [id]);
    } else if (c.user_b_id === userId) {
      await pool.execute('UPDATE conversations SET user_b_deleted = 1 WHERE id = ?', [id]);
    } else {
      return fail(res, 'not_member_of_conversation', 403);
    }

    return res.json(ok({ message: 'deleted' }));
  } catch (err) {
    console.error('Delete conversation error:', err);
    return fail(res, 'internal_error', 500);
  }
});

export default router;