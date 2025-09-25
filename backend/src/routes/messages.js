import express from 'express';
import { z } from 'zod';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';
import { generateId } from '../utils/id-generator.js';

const router = express.Router();

const sendMessageSchema = z.object({
  conversation_id: z.string().optional(),
  other_user_id: z.string().optional(),
  type: z.enum(['text', 'image', 'video', 'voice', 'file']),
  text: z.string().optional(),
  reply_to_message_id: z.string().optional(),
  attachments: z
    .array(
      z.object({
        type: z.enum(['image', 'video', 'voice', 'document']),
        url: z.string().url(),
        thumbnail: z.string().url().optional(),
        durationSec: z.number().int().optional(),
        fileSize: z.number().int().optional(),
        fileName: z.string().optional(),
      })
    )
    .optional(),
});

function normalizePair(a, b) {
  return a < b ? [a, b] : [b, a];
}

async function getOrCreateConversation(userId, otherUserId) {
  const [a, b] = normalizePair(userId, otherUserId);
  const [existing] = await pool.execute(
    'SELECT * FROM conversations WHERE user_a_id = ? AND user_b_id = ? LIMIT 1',
    [a, b]
  );
  if (existing.length > 0) return existing[0].id;
  const id = generateId();
  await pool.execute(
    'INSERT INTO conversations (id, user_a_id, user_b_id, created_at, updated_at) VALUES (?, ?, ?, NOW(), NOW())',
    [id, a, b]
  );
  return id;
}

// List latest messages in a conversation (paginated backwards)
router.get('/:conversationId', async (req, res) => {
  try {
    const userId = req.user?.id;
    const { conversationId } = req.params;

    const limitRaw = parseInt(req.query.limit || '50', 10);
    const limit = Number.isFinite(limitRaw)
      ? Math.min(Math.max(limitRaw, 1), 100)
      : 50;

    if (!userId) return fail(res, 'user_not_authenticated', 401);
    if (!conversationId) return fail(res, 'conversation_id_required', 400);

    const [convRows] = await pool.execute(
      'SELECT * FROM conversations WHERE id = ? AND (user_a_id = ? OR user_b_id = ?) LIMIT 1',
      [conversationId, userId, userId]
    );
    if (convRows.length === 0) return fail(res, 'conversation_not_found', 404);

    const sqlMessages = `
      SELECT m.*,
             reply_msg.id as reply_id,
             reply_msg.sender_id as reply_sender_id,
             reply_msg.type as reply_type,
             reply_msg.text as reply_text,
             reply_sender.first_name as reply_sender_first_name,
             reply_sender.last_name as reply_sender_last_name,
             reply_sender.username as reply_sender_username
        FROM chat_messages m
        LEFT JOIN chat_messages reply_msg ON m.reply_to_message_id = reply_msg.id
        LEFT JOIN profiles reply_sender ON reply_msg.sender_id = reply_sender.user_id
       WHERE m.conversation_id = ?
       ORDER BY m.created_at DESC
       LIMIT ${limit}
    `;
    const [rows] = await pool.query(sqlMessages, [conversationId.toString()]);

    const messageIds = rows.map((r) => r.id);

    // Attachments
    let attachmentsByMsg = {};
    if (messageIds.length > 0) {
      const placeholders = messageIds.map(() => '?').join(',');
      const [attRows] = await pool.query(
        `SELECT * FROM chat_attachments WHERE message_id IN (${placeholders})`,
        messageIds
      );
      attachmentsByMsg = attRows.reduce((acc, a) => {
        (acc[a.message_id] = acc[a.message_id] || []).push(a);
        return acc;
      }, {});
    }

    // Reactions by current user
    let myReactions = {};
    if (messageIds.length > 0) {
      const placeholders = messageIds.map(() => '?').join(',');
      const [reRows] = await pool.query(
        `SELECT * FROM chat_reactions WHERE message_id IN (${placeholders}) AND user_id = ?`,
        [...messageIds, userId]
      );
      myReactions = reRows.reduce((acc, r) => {
        acc[r.message_id] = r.emoji;
        return acc;
      }, {});
    }

    // Latest reaction by anyone
    let anyReactions = {};
    if (messageIds.length > 0) {
      const placeholders = messageIds.map(() => '?').join(',');
      const [allReRows] = await pool.query(
        `SELECT r1.*
           FROM chat_reactions r1
           JOIN (
             SELECT message_id, MAX(updated_at) AS max_updated
             FROM chat_reactions
             WHERE message_id IN (${placeholders})
             GROUP BY message_id
           ) r2 ON r1.message_id = r2.message_id AND r1.updated_at = r2.max_updated`,
        messageIds
      );
      anyReactions = allReRows.reduce((acc, r) => {
        acc[r.message_id] = r.emoji;
        return acc;
      }, {});
    }

    const messages = rows
      .reverse()
      .map((m) => ({
        id: m.id,
        conversation_id: m.conversation_id,
        sender_id: m.sender_id,
        receiver_id: m.receiver_id,
        type: m.type,
        text: m.text,
        reply_to: m.reply_id
          ? {
              message_id: m.reply_id,
              sender_name:
                m.reply_sender_first_name && m.reply_sender_last_name
                  ? `${m.reply_sender_first_name} ${m.reply_sender_last_name}`.trim()
                  : m.reply_sender_username || 'User',
              content: m.reply_text || '',
              type: m.reply_type || 'text',
            }
          : null,
        read_at: m.read_at,
        created_at: m.created_at,
        attachments: (attachmentsByMsg[m.id] || []).map((a) => ({
          id: a.id,
          type: a.type,
          url: a.url,
          thumbnail: a.thumbnail,
          durationSec: a.durationSec,
          fileSize: a.fileSize,
          fileName: a.fileName,
        })),
        my_reaction: myReactions[m.id] || null,
        reaction: anyReactions[m.id] || null,
      }));

    return res.json(ok({ messages }));
  } catch (err) {
    console.error('List messages error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Send a message (text/media/voice)
router.post('/', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return fail(res, 'user_not_authenticated', 401);

    const body = sendMessageSchema.parse(req.body);

    if (!body.conversation_id && !body.other_user_id) {
      return fail(res, 'conversation_or_other_user_required', 400);
    }

    let conversationId = body.conversation_id || null;
    let receiverId = null;

    if (!conversationId) {
      receiverId = body.other_user_id;
      const [u] = await pool.execute('SELECT id FROM users WHERE id = ? LIMIT 1', [receiverId]);
      if (u.length === 0) return fail(res, 'other_user_not_found', 404);
      conversationId = await getOrCreateConversation(userId, receiverId);
    } else {
      const [convRows] = await pool.execute('SELECT * FROM conversations WHERE id = ? LIMIT 1', [conversationId]);
      if (convRows.length === 0) return fail(res, 'conversation_not_found', 404);
      const c = convRows[0];
      if (c.user_a_id !== userId && c.user_b_id !== userId) {
        return fail(res, 'not_member_of_conversation', 403);
      }
      receiverId = c.user_a_id === userId ? c.user_b_id : c.user_a_id;
    }

    const id = generateId();
    const text = body.text || '';

    await pool.execute(
      `INSERT INTO chat_messages (id, conversation_id, sender_id, receiver_id, type, text, reply_to_message_id, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())`,
      [id, conversationId, userId, receiverId, body.type, text, body.reply_to_message_id || null]
    );

    // Persist attachments (image, video, voice, document)
    const attachmentsIn = body.attachments || [];
    const attachmentsOut = [];
    for (const att of attachmentsIn) {
      const attId = generateId();
      await pool.execute(
        `INSERT INTO chat_attachments (id, message_id, type, url, thumbnail, durationSec, fileSize, fileName, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
        [
          attId,
          id,
          att.type,
          att.url,
          att.thumbnail || null,
          att.durationSec || null,
          att.fileSize || null,
          att.fileName || null,
        ]
      );
      attachmentsOut.push({
        id: attId,
        type: att.type,
        url: att.url,
        thumbnail: att.thumbnail || null,
        durationSec: att.durationSec || null,
        fileSize: att.fileSize || null,
        fileName: att.fileName || null,
      });
    }

    await pool.execute(
      `UPDATE conversations 
         SET last_message_type = ?, last_message_text = ?, last_message_at = NOW(), updated_at = NOW()
       WHERE id = ?`,
      [
        body.type,
        text ||
          (attachmentsIn.length > 0
            ? attachmentsIn[0].type === 'image'
              ? 'Photo'
              : attachmentsIn[0].type === 'video'
              ? 'Video'
              : attachmentsIn[0].type === 'voice'
              ? 'Voice message'
              : 'File'
            : null),
        conversationId,
      ]
    );

    return res.json(
      ok({
        message: {
          id,
          conversation_id: conversationId,
          sender_id: userId,
          receiver_id: receiverId,
          type: body.type,
          text,
          created_at: new Date(),
          attachments: attachmentsOut, // return persisted attachment records with IDs
          my_reaction: null,
          reaction: null,
        },
      })
    );
  } catch (err) {
    if (err instanceof z.ZodError) {
      return fail(res, 'validation_error', 400, err.errors);
    }
    console.error('Send message error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// React / Unreact to a message
router.post('/:messageId/react', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return fail(res, 'user_not_authenticated', 401);

    const { messageId } = req.params;
    const { emoji } = req.body || {};

    const [rows] = await pool.execute('SELECT * FROM chat_messages WHERE id = ? LIMIT 1', [messageId]);
    if (rows.length === 0) return fail(res, 'message_not_found', 404);

    if (!emoji) {
      await pool.execute('DELETE FROM chat_reactions WHERE message_id = ? AND user_id = ?', [messageId, userId]);
      return res.json(ok({ message: 'reaction_removed' }));
    }

    // Upsert
    const [existing] = await pool.execute(
      'SELECT * FROM chat_reactions WHERE message_id = ? AND user_id = ? LIMIT 1',
      [messageId, userId]
    );
    if (existing.length > 0) {
      await pool.execute(
        'UPDATE chat_reactions SET emoji = ?, updated_at = NOW() WHERE message_id = ? AND user_id = ?',
        [emoji, messageId, userId]
      );
    } else {
      const id = generateId();
      await pool.execute(
        'INSERT INTO chat_reactions (id, message_id, user_id, emoji, created_at, updated_at) VALUES (?, ?, ?, ?, NOW(), NOW())',
        [id, messageId, userId, emoji]
      );
    }

    return res.json(ok({ message: 'reaction_saved', emoji }));
  } catch (err) {
    console.error('React error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Mark a single message as read
router.post('/:messageId/read', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return fail(res, 'user_not_authenticated', 401);

    const { messageId } = req.params;

    const [rows] = await pool.execute('SELECT * FROM chat_messages WHERE id = ? LIMIT 1', [messageId]);
    if (rows.length === 0) return fail(res, 'message_not_found', 404);

    const msg = rows[0];
    if (msg.receiver_id !== userId) return fail(res, 'not_message_receiver', 403);

    await pool.execute('UPDATE chat_messages SET read_at = NOW() WHERE id = ? AND read_at IS NULL', [messageId]);
    return res.json(ok({ message: 'marked_read' }));
  } catch (err) {
    console.error('Mark single message read error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// Delete message (sender only)
router.delete('/:messageId', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return fail(res, 'user_not_authenticated', 401);

    const { messageId } = req.params;

    const [rows] = await pool.execute('SELECT * FROM chat_messages WHERE id = ? LIMIT 1', [messageId]);
    if (rows.length === 0) return fail(res, 'message_not_found', 404);

    const msg = rows[0];
    if (msg.sender_id !== userId) return fail(res, 'not_message_sender', 403);

    await pool.execute('DELETE FROM chat_messages WHERE id = ?', [messageId]);
    return res.json(ok({ message: 'deleted' }));
  } catch (err) {
    console.error('Delete message error:', err);
    return fail(res, 'internal_error', 500);
  }
});

export default router;