import express from 'express';
import { z } from 'zod';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';
import { generateId } from '../utils/id-generator.js';
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const router = express.Router();

// S3 signing for read
const REGION = process.env.AWS_REGION || 'ca-central-1';
const BUCKET = process.env.S3_BUCKET || 'nexum-uploads';
const s3Client = new S3Client({ region: REGION });

function extractKeyFromUrl(url) {
  try {
    const u = new URL(url);
    const host = u.host;
    if (host.startsWith(`${BUCKET}.s3.`)) {
      return decodeURIComponent(u.pathname.replace(/^\//, ''));
    }
    if (host.startsWith(`s3.${REGION}.amazonaws.com`) && u.pathname.startsWith(`/${BUCKET}/`)) {
      return decodeURIComponent(u.pathname.substring(BUCKET.length + 2));
    }
    return null;
  } catch {
    return null;
  }
}
function isAlreadySigned(url) {
  return (
    url.includes('X-Amz-Algorithm=') ||
    url.includes('X-Amz-Signature=') ||
    url.includes('X-Amz-Credential=')
  );
}
async function ensureReadableUrl(url) {
  try {
    if (!url || isAlreadySigned(url)) return url;
    const key = extractKeyFromUrl(url);
    if (!key) return url;
    const cmd = new GetObjectCommand({ Bucket: BUCKET, Key: key });
    const ttl = parseInt(process.env.S3_SIGNED_GET_TTL || '604800', 10);
    return await getSignedUrl(s3Client, cmd, { expiresIn: ttl });
  } catch (e) {
    console.error('Failed to sign read URL:', e);
    return url;
  }
}

async function updateMentorshipConversationLastMessage(conversationId) {
  try {
    const [rows] = await pool.execute(
      `SELECT type, text, created_at 
         FROM mentorship_messages 
        WHERE conversation_id = ? 
        ORDER BY created_at DESC 
        LIMIT 1`,
      [conversationId]
    );
    if (rows.length === 0) {
      await pool.execute(
        `UPDATE mentorship_conversations 
           SET last_message_type = NULL, 
               last_message_text = NULL, 
               last_message_at = NULL, 
               updated_at = NOW()
         WHERE id = ?`,
        [conversationId]
      );
      return;
    }
    const m = rows[0];
    const label =
      m.text ||
      (m.type === 'image'
        ? 'Photo'
        : m.type === 'video'
        ? 'Video'
        : m.type === 'voice'
        ? 'Voice message'
        : m.type === 'file'
        ? 'File'
        : null);
    await pool.execute(
      `UPDATE mentorship_conversations 
          SET last_message_type = ?, 
              last_message_text = ?, 
              last_message_at = ?, 
              updated_at = NOW()
        WHERE id = ?`,
      [m.type, label, m.created_at, conversationId]
    );
  } catch (e) {
    console.error('Failed to update mentorship conversation last message:', e);
  }
}

// ---------- Mentorship Conversations ----------
router.get('/conversations', async (req, res) => {
  try {
    const userId = req.user.id;
    const sql = `
      SELECT 
        c.*,
        CASE WHEN c.mentor_user_id = ? THEN c.mentee_user_id ELSE c.mentor_user_id END AS other_user_id,
        p.first_name, p.last_name, p.username, p.profile_photo_url,
        (SELECT COUNT(*) FROM mentorship_messages m 
           WHERE m.conversation_id = c.id AND m.receiver_id = ? 
             AND m.read_at IS NULL
             AND m.id NOT IN (SELECT message_id FROM mentorship_message_hides WHERE user_id = ?)
        ) AS unread_count,
        (SELECT m.sender_id FROM mentorship_messages m 
           WHERE m.conversation_id = c.id
             AND m.id NOT IN (SELECT message_id FROM mentorship_message_hides WHERE user_id = ?)
           ORDER BY m.created_at DESC LIMIT 1) AS eff_last_sender_id,
        (SELECT IF(m.read_at IS NULL, 0, 1) FROM mentorship_messages m 
           WHERE m.conversation_id = c.id
             AND m.id NOT IN (SELECT message_id FROM mentorship_message_hides WHERE user_id = ?)
           ORDER BY m.created_at DESC LIMIT 1) AS eff_last_read_flag,
        (SELECT m.type FROM mentorship_messages m 
           WHERE m.conversation_id = c.id
             AND m.id NOT IN (SELECT message_id FROM mentorship_message_hides WHERE user_id = ?)
           ORDER BY m.created_at DESC LIMIT 1) AS eff_last_message_type,
        (SELECT m.text FROM mentorship_messages m 
           WHERE m.conversation_id = c.id
             AND m.id NOT IN (SELECT message_id FROM mentorship_message_hides WHERE user_id = ?)
           ORDER BY m.created_at DESC LIMIT 1) AS eff_last_message_text,
        (SELECT m.created_at FROM mentorship_messages m 
           WHERE m.conversation_id = c.id
             AND m.id NOT IN (SELECT message_id FROM mentorship_message_hides WHERE user_id = ?)
           ORDER BY m.created_at DESC LIMIT 1) AS eff_last_message_at
      FROM mentorship_conversations c
      LEFT JOIN profiles p 
        ON p.user_id = (CASE WHEN c.mentor_user_id = ? THEN c.mentee_user_id ELSE c.mentor_user_id END)
      WHERE ((c.mentor_user_id = ? AND c.mentor_deleted = 0) OR (c.mentee_user_id = ? AND c.mentee_deleted = 0))
      ORDER BY (eff_last_message_at IS NULL), eff_last_message_at DESC
    `;
    // Fix: 11 placeholders, pass 11 params
    const a = [userId, userId, userId, userId, userId, userId, userId, userId, userId, userId, userId];
    const [rows] = await pool.execute(sql, a);

    const conversations = rows.map((r) => {
      const first = (r.first_name || '').trim();
      const last = (r.last_name || '').trim();
      const name = (first || last) ? `${first} ${last}`.trim() : (r.username ? `@${r.username}` : 'User');
      const isMentor = r.mentor_user_id === userId;
      return {
        id: r.id,
        mentor_user_id: isMentor ? userId : r.other_user_id,
        mentor: { id: r.other_user_id, name, avatarUrl: r.profile_photo_url || null, isOnline: false },
        last_message_type: r.eff_last_message_type || r.last_message_type || null,
        last_message_text: r.eff_last_message_text || r.last_message_text || null,
        last_message_at: r.eff_last_message_at || r.last_message_at || null,
        unread_count: Number(r.unread_count || 0),
        muted: isMentor ? !!r.mentor_muted : !!r.mentee_muted,
        last_from_current_user: r.eff_last_sender_id ? r.eff_last_sender_id === userId : null,
        last_read: r.eff_last_read_flag != null ? r.eff_last_read_flag === 1 : null,
      };
    });

    return res.json(ok({ conversations }));
  } catch (e) {
    console.error('Mentorship conversations error:', e);
    return fail(res, 'internal_error', 500);
  }
});

router.post('/conversations', async (req, res) => {
  try {
    const userId = req.user.id;
    const { mentor_user_id } = req.body || {};
    if (!mentor_user_id || typeof mentor_user_id !== 'string') return fail(res, 'mentor_user_id_required', 400);

    // Existing?
    const [existing] = await pool.execute(
      `SELECT id FROM mentorship_conversations 
       WHERE (mentor_user_id = ? AND mentee_user_id = ?) 
          OR (mentor_user_id = ? AND mentee_user_id = ?)
       LIMIT 1`,
      [mentor_user_id, userId, userId, mentor_user_id]
    );
    if (existing.length > 0) return res.json(ok({ conversation: { id: existing[0].id } }));

    const id = generateId();

    // If there's a relation where other is mentor and current is mentee
    const [rel1] = await pool.execute(
      'SELECT id FROM mentorship_relations WHERE mentor_user_id = ? AND mentee_user_id = ? LIMIT 1',
      [mentor_user_id, userId]
    );
    if (rel1.length > 0) {
      await pool.execute(
        'INSERT INTO mentorship_conversations (id, mentor_user_id, mentee_user_id, created_at, updated_at) VALUES (?, ?, ?, NOW(), NOW())',
        [id, mentor_user_id, userId]
      );
    } else {
      // Current user might be mentor; ensure relation
      const [rel2] = await pool.execute(
        'SELECT id FROM mentorship_relations WHERE mentor_user_id = ? AND mentee_user_id = ? LIMIT 1',
        [userId, mentor_user_id]
      );
      if (rel2.length === 0) {
        const rid = generateId();
        await pool.execute(
          'INSERT INTO mentorship_relations (id, mentor_user_id, mentee_user_id, created_at) VALUES (?, ?, ?, NOW())',
          [rid, userId, mentor_user_id]
        );
      }
      await pool.execute(
        'INSERT INTO mentorship_conversations (id, mentor_user_id, mentee_user_id, created_at, updated_at) VALUES (?, ?, ?, NOW(), NOW())',
        [id, userId, mentor_user_id]
      );
    }

    return res.json(ok({ conversation: { id } }));
  } catch (e) {
    console.error('Mentorship ensure conversation error:', e);
    return fail(res, 'internal_error', 500);
  }
});

router.post('/conversations/:id/mark-read', async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const [rows] = await pool.execute(
      'SELECT * FROM mentorship_conversations WHERE id = ? LIMIT 1',
      [id]
    );
    if (rows.length === 0) return fail(res, 'conversation_not_found', 404);
    const c = rows[0];

    const field =
      c.mentor_user_id === userId ? 'mentor_last_read_at' :
      c.mentee_user_id === userId ? 'mentee_last_read_at' : null;
    if (!field) return fail(res, 'not_member_of_conversation', 403);

    await pool.execute(`UPDATE mentorship_conversations SET ${field} = NOW() WHERE id = ?`, [id]);
    await pool.execute(
      'UPDATE mentorship_messages SET read_at = NOW() WHERE conversation_id = ? AND receiver_id = ? AND read_at IS NULL',
      [id, userId]
    );

    return res.json(ok({ message: 'marked_read' }));
  } catch (err) {
    console.error('Mentorship mark read error:', err);
    return fail(res, 'internal_error', 500);
  }
});

router.post('/conversations/:id/mute', async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;
    const [rows] = await pool.execute('SELECT * FROM mentorship_conversations WHERE id = ? LIMIT 1', [id]);
    if (rows.length === 0) return fail(res, 'conversation_not_found', 404);
    const c = rows[0];
    if (c.mentor_user_id === userId) {
      await pool.execute('UPDATE mentorship_conversations SET mentor_muted = 1 WHERE id = ?', [id]);
    } else if (c.mentee_user_id === userId) {
      await pool.execute('UPDATE mentorship_conversations SET mentee_muted = 1 WHERE id = ?', [id]);
    } else {
      return fail(res, 'not_member_of_conversation', 403);
    }
    return res.json(ok({ message: 'muted' }));
  } catch (e) {
    console.error('Mentorship mute error:', e);
    return fail(res, 'internal_error', 500);
  }
});

router.post('/conversations/:id/unmute', async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;
    const [rows] = await pool.execute('SELECT * FROM mentorship_conversations WHERE id = ? LIMIT 1', [id]);
    if (rows.length === 0) return fail(res, 'conversation_not_found', 404);
    const c = rows[0];
    if (c.mentor_user_id === userId) {
      await pool.execute('UPDATE mentorship_conversations SET mentor_muted = 0 WHERE id = ?', [id]);
    } else if (c.mentee_user_id === userId) {
      await pool.execute('UPDATE mentorship_conversations SET mentee_muted = 0 WHERE id = ?', [id]);
    } else {
      return fail(res, 'not_member_of_conversation', 403);
    }
    return res.json(ok({ message: 'unmuted' }));
  } catch (e) {
    console.error('Mentorship unmute error:', e);
    return fail(res, 'internal_error', 500);
  }
});

router.delete('/conversations/:id', async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;
    const [rows] = await pool.execute('SELECT * FROM mentorship_conversations WHERE id = ? LIMIT 1', [id]);
    if (rows.length === 0) return fail(res, 'conversation_not_found', 404);
    const c = rows[0];
    if (c.mentor_user_id === userId) {
      await pool.execute('UPDATE mentorship_conversations SET mentor_deleted = 1 WHERE id = ?', [id]);
    } else if (c.mentee_user_id === userId) {
      await pool.execute('UPDATE mentorship_conversations SET mentee_deleted = 1 WHERE id = ?', [id]);
    } else {
      return fail(res, 'not_member_of_conversation', 403);
    }
    return res.json(ok({ message: 'deleted' }));
  } catch (e) {
    console.error('Mentorship delete conversation error:', e);
    return fail(res, 'internal_error', 500);
  }
});

// ---------- Mentorship Messages ----------
const sendMessageSchema = z.object({
  conversation_id: z.string().optional(),
  mentor_user_id: z.string().optional(),
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

router.get('/messages/:conversationId', async (req, res) => {
  try {
    const userId = req.user?.id;
    const { conversationId } = req.params;
    const limitRaw = parseInt(req.query.limit || '50', 10);
    const limit = Number.isFinite(limitRaw) ? Math.min(Math.max(limitRaw, 1), 100) : 50;

    if (!userId) return fail(res, 'user_not_authenticated', 401);

    const [convRows] = await pool.execute(
      'SELECT * FROM mentorship_conversations WHERE id = ? AND (mentor_user_id = ? OR mentee_user_id = ?) LIMIT 1',
      [conversationId, userId, userId]
    );
    if (convRows.length === 0) return fail(res, 'conversation_not_found', 404);

    const sql = `
      SELECT m.*,
             reply_msg.id as reply_id,
             reply_msg.sender_id as reply_sender_id,
             reply_msg.type as reply_type,
             reply_msg.text as reply_text,
             reply_sender.first_name as reply_sender_first_name,
             reply_sender.last_name as reply_sender_last_name,
             reply_sender.username as reply_sender_username
        FROM mentorship_messages m
        LEFT JOIN mentorship_messages reply_msg ON m.reply_to_message_id = reply_msg.id
        LEFT JOIN profiles reply_sender ON reply_msg.sender_id = reply_sender.user_id
       WHERE m.conversation_id = ?
         AND m.id NOT IN (
           SELECT message_id FROM mentorship_message_hides WHERE user_id = ?
         )
       ORDER BY m.created_at DESC
       LIMIT ${limit}
    `;
    const [rows] = await pool.query(sql, [conversationId.toString(), userId]);
    const messageIds = rows.map((r) => r.id);

    let attachmentsByMsg = {};
    if (messageIds.length > 0) {
      const placeholders = messageIds.map(() => '?').join(',');
      const [attRows] = await pool.query(
        `SELECT * FROM mentorship_attachments WHERE message_id IN (${placeholders})`,
        messageIds
      );
      const processed = {};
      for (const a of attRows) {
        const url = await ensureReadableUrl(a.url);
        (processed[a.message_id] = processed[a.message_id] || []).push({
          id: a.id,
          type: a.type,
          url,
          thumbnail: a.thumbnail,
          durationSec: a.durationSec,
          fileSize: a.fileSize,
          fileName: a.fileName,
        });
      }
      attachmentsByMsg = processed;
    }

    let myReactions = {};
    if (messageIds.length > 0) {
      const placeholders = messageIds.map(() => '?').join(',');
      const [reRows] = await pool.query(
        `SELECT * FROM mentorship_reactions WHERE message_id IN (${placeholders}) AND user_id = ?`,
        [...messageIds, userId]
      );
      myReactions = reRows.reduce((acc, r) => {
        acc[r.message_id] = r.emoji;
        return acc;
      }, {});
    }

    let anyReactions = {};
    if (messageIds.length > 0) {
      const placeholders = messageIds.map(() => '?').join(',');
      const [allReRows] = await pool.query(
        `SELECT r1.*
           FROM mentorship_reactions r1
           JOIN (
             SELECT message_id, MAX(updated_at) AS max_updated
             FROM mentorship_reactions
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

    const messages = rows.reverse().map((m) => ({
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
      attachments: attachmentsByMsg[m.id] || [],
      my_reaction: myReactions[m.id] || null,
      reaction: anyReactions[m.id] || null,
    }));

    return res.json(ok({ messages }));
  } catch (err) {
    console.error('Mentorship list messages error:', err);
    return fail(res, 'internal_error', 500);
  }
});

router.post('/messages', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return fail(res, 'user_not_authenticated', 401);
    const body = sendMessageSchema.parse(req.body);

    if (!body.conversation_id && !body.mentor_user_id && !body.other_user_id) {
      return fail(res, 'conversation_or_user_required', 400);
    }

    let conversationId = body.conversation_id || null;
    let receiverId = null;

    if (!conversationId) {
      const targetId = body.mentor_user_id || body.other_user_id;
      if (!targetId) return fail(res, 'mentor_user_id_or_other_user_id_required', 400);

      const [existing] = await pool.execute(
        `SELECT id FROM mentorship_conversations 
         WHERE (mentor_user_id = ? AND mentee_user_id = ?) 
            OR (mentor_user_id = ? AND mentee_user_id = ?)
         LIMIT 1`,
        [targetId, userId, userId, targetId]
      );

      if (existing.length > 0) {
        conversationId = existing[0].id;
      } else {
        const id = generateId();
        const [rel1] = await pool.execute(
          'SELECT id FROM mentorship_relations WHERE mentor_user_id = ? AND mentee_user_id = ? LIMIT 1',
          [targetId, userId]
        );
        if (rel1.length > 0) {
          await pool.execute(
            'INSERT INTO mentorship_conversations (id, mentor_user_id, mentee_user_id, created_at, updated_at) VALUES (?, ?, ?, NOW(), NOW())',
            [id, targetId, userId]
          );
        } else {
          await pool.execute(
            'INSERT INTO mentorship_conversations (id, mentor_user_id, mentee_user_id, created_at, updated_at) VALUES (?, ?, ?, NOW(), NOW())',
            [id, userId, targetId]
          );
          const [rel2] = await pool.execute(
            'SELECT id FROM mentorship_relations WHERE mentor_user_id = ? AND mentee_user_id = ? LIMIT 1',
            [userId, targetId]
          );
          if (rel2.length === 0) {
            const rid = generateId();
            await pool.execute(
              'INSERT INTO mentorship_relations (id, mentor_user_id, mentee_user_id, created_at) VALUES (?, ?, ?, NOW())',
              [rid, userId, targetId]
            );
          }
        }
        conversationId = id;
      }
      receiverId = targetId;
    } else {
      const [convRows] = await pool.execute(
        'SELECT * FROM mentorship_conversations WHERE id = ? LIMIT 1',
        [conversationId]
      );
      if (convRows.length === 0) return fail(res, 'conversation_not_found', 404);
      const c = convRows[0];
      if (c.mentor_user_id !== userId && c.mentee_user_id !== userId) {
        return fail(res, 'not_member_of_conversation', 403);
      }
      receiverId = c.mentor_user_id === userId ? c.mentee_user_id : c.mentor_user_id;
    }

    const id = generateId();
    const text = body.text || '';

    await pool.execute(
      `INSERT INTO mentorship_messages (id, conversation_id, sender_id, receiver_id, type, text, reply_to_message_id, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())`,
      [id, conversationId, userId, receiverId, body.type, text, body.reply_to_message_id || null]
    );

    const attachmentsIn = body.attachments || [];
    const attachmentsOut = [];
    for (const att of attachmentsIn) {
      const attId = generateId();
      await pool.execute(
        `INSERT INTO mentorship_attachments (id, message_id, type, url, thumbnail, durationSec, fileSize, fileName, created_at)
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
      const signedUrl = await ensureReadableUrl(att.url);
      attachmentsOut.push({
        id: attId,
        type: att.type,
        url: signedUrl,
        thumbnail: att.thumbnail || null,
        durationSec: att.durationSec || null,
        fileSize: att.fileSize || null,
        fileName: att.fileName || null,
      });
    }

    await updateMentorshipConversationLastMessage(conversationId);

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
          attachments: attachmentsOut,
          my_reaction: null,
          reaction: null,
        },
      })
    );
  } catch (err) {
    if (err instanceof z.ZodError) return fail(res, 'validation_error', 400, err.errors);
    console.error('Mentorship send message error:', err);
    return fail(res, 'internal_error', 500);
  }
});

router.post('/messages/:messageId/react', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return fail(res, 'user_not_authenticated', 401);
    const { messageId } = req.params;
    const { emoji } = req.body || {};

    const [rows] = await pool.execute('SELECT * FROM mentorship_messages WHERE id = ? LIMIT 1', [messageId]);
    if (rows.length === 0) return fail(res, 'message_not_found', 404);

    if (!emoji) {
      await pool.execute('DELETE FROM mentorship_reactions WHERE message_id = ? AND user_id = ?', [messageId, userId]);
      return res.json(ok({ message: 'reaction_removed' }));
    }

    const [existing] = await pool.execute(
      'SELECT * FROM mentorship_reactions WHERE message_id = ? AND user_id = ? LIMIT 1',
      [messageId, userId]
    );
    if (existing.length > 0) {
      await pool.execute(
        'UPDATE mentorship_reactions SET emoji = ?, updated_at = NOW() WHERE message_id = ? AND user_id = ?',
        [emoji, messageId, userId]
      );
    } else {
      const id = generateId();
      await pool.execute(
        'INSERT INTO mentorship_reactions (id, message_id, user_id, emoji, created_at, updated_at) VALUES (?, ?, ?, ?, NOW(), NOW())',
        [id, messageId, userId, emoji]
      );
    }

    return res.json(ok({ message: 'reaction_saved', emoji }));
  } catch (err) {
    console.error('Mentorship react error:', err);
    return fail(res, 'internal_error', 500);
  }
});

router.post('/messages/:messageId/read', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return fail(res, 'user_not_authenticated', 401);
    const { messageId } = req.params;

    const [rows] = await pool.execute('SELECT * FROM mentorship_messages WHERE id = ? LIMIT 1', [messageId]);
    if (rows.length === 0) return fail(res, 'message_not_found', 404);

    const msg = rows[0];
    if (msg.receiver_id !== userId) return fail(res, 'not_message_receiver', 403);

    await pool.execute('UPDATE mentorship_messages SET read_at = NOW() WHERE id = ? AND read_at IS NULL', [messageId]);
    return res.json(ok({ message: 'marked_read' }));
  } catch (err) {
    console.error('Mentorship mark single read error:', err);
    return fail(res, 'internal_error', 500);
  }
});

router.post('/messages/:messageId/delete-for-me', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return fail(res, 'user_not_authenticated', 401);
    const { messageId } = req.params;

    const [rows] = await pool.execute(
      'SELECT conversation_id, sender_id, receiver_id FROM mentorship_messages WHERE id = ? LIMIT 1',
      [messageId]
    );
    if (rows.length === 0) return fail(res, 'message_not_found', 404);
    const msg = rows[0];
    if (msg.sender_id !== userId && msg.receiver_id !== userId) {
      return fail(res, 'not_in_conversation', 403);
    }

    await pool.execute(
      `INSERT INTO mentorship_message_hides (message_id, user_id) 
       VALUES (?, ?) 
       ON DUPLICATE KEY UPDATE user_id = user_id`,
      [messageId, userId]
    );

    return res.json(ok({ message: 'deleted_for_me' }));
  } catch (err) {
    console.error('Mentorship delete for me error:', err);
    return fail(res, 'internal_error', 500);
  }
});

router.post('/messages/:messageId/delete-for-everyone', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return fail(res, 'user_not_authenticated', 401);
    const { messageId } = req.params;

    const [rows] = await pool.execute('SELECT * FROM mentorship_messages WHERE id = ? LIMIT 1', [messageId]);
    if (rows.length === 0) return fail(res, 'message_not_found', 404);

    const msg = rows[0];
    if (msg.sender_id !== userId) return fail(res, 'not_message_sender', 403);

    await pool.execute('DELETE FROM mentorship_messages WHERE id = ?', [messageId]);
    await updateMentorshipConversationLastMessage(msg.conversation_id);

    return res.json(ok({ message: 'deleted_for_everyone' }));
  } catch (err) {
    console.error('Mentorship delete for everyone error:', err);
    return fail(res, 'internal_error', 500);
  }
});

// ---------- Professional fields ----------
router.get('/fields', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      'SELECT id, name, icon, description FROM mentorship_fields ORDER BY name ASC'
    );
    const fields = rows.map(r => ({
      id: r.id,
      name: r.name,
      icon: r.icon || '',
      description: r.description || null,
      mentor_count: 0,
    }));
    return res.json(ok({ fields }));
  } catch (e) {
    console.error('List fields error:', e);
    return fail(res, 'internal_error', 500);
  }
});

// ---------- Requests ----------
router.post('/requests', async (req, res) => {
  try {
    const userId = req.user.id;
    const schema = z.object({
      field_id: z.string(),
      message: z.string().min(1).max(5000),
    });
    const body = schema.parse(req.body);

    const [exists] = await pool.execute(
      'SELECT id FROM mentorship_fields WHERE id = ? LIMIT 1',
      [body.field_id]
    );
    if (exists.length === 0) return fail(res, 'field_not_found', 404);

    const id = generateId();
    await pool.execute(
      `INSERT INTO mentorship_requests (id, requester_user_id, field_id, message, status, created_at, updated_at)
       VALUES (?, ?, ?, ?, 'pending', NOW(), NOW())`,
      [id, userId, body.field_id, body.message]
    );
    return res.json(ok({ request: { id, status: 'pending' } }));
  } catch (e) {
    if (e instanceof z.ZodError) return fail(res, 'validation_error', 400, e.errors);
    console.error('Create mentorship request error:', e);
    return fail(res, 'internal_error', 500);
  }
});

// ---------- My mentors ----------
router.get('/mentors', async (req, res) => {
  try {
    const userId = req.user.id;

    let rows = [];
    try {
      const result = await pool.execute(
        `SELECT 
           r.mentor_user_id AS id,
           p.first_name, p.last_name, p.username, p.profile_photo_url, 
           p.professional_experiences, p.bio, p.interest_domains
         FROM mentorship_relations r
         LEFT JOIN profiles p ON p.user_id = r.mentor_user_id
         WHERE r.mentee_user_id = ?`,
        [userId]
      );
      rows = result[0];
    } catch (e) {
      // Table may not exist yet; derive mentors from conversations as a fallback
      if (e && (e.code === 'ER_NO_SUCH_TABLE' || e.errno === 1146)) {
        const [convRows] = await pool.execute(
          `SELECT DISTINCT
             CASE WHEN c.mentor_user_id = ? THEN c.mentee_user_id ELSE c.mentor_user_id END AS id
           FROM mentorship_conversations c
           WHERE (c.mentor_user_id = ? OR c.mentee_user_id = ?)
             AND ((c.mentor_user_id = ? AND c.mentor_deleted = 0) OR (c.mentee_user_id = ? AND c.mentee_deleted = 0))`,
          [userId, userId, userId, userId, userId]
        );
        const ids = convRows.map(r => r.id).filter(Boolean);
        if (ids.length > 0) {
          const placeholders = ids.map(() => '?').join(',');
          const [pRows] = await pool.query(
            `SELECT 
               user_id AS id,
               first_name, last_name, username, profile_photo_url, 
               professional_experiences, bio, interest_domains
             FROM profiles WHERE user_id IN (${placeholders})`,
            ids
          );
          rows = pRows;
        } else {
          rows = [];
        }
      } else {
        throw e;
      }
    }

    const [rateRows] = await pool.execute(
      `SELECT mentor_user_id AS id, AVG(rating) AS avg_rating, COUNT(*) AS review_count
         FROM mentorship_reviews GROUP BY mentor_user_id`
    );
    const ratingMap = {};
    for (const rr of rateRows) {
      ratingMap[rr.id] = {
        rating: rr.avg_rating ? Number(rr.avg_rating).toFixed(1) : null,
        reviewCount: rr.review_count ? Number(rr.review_count) : 0,
      };
    }

    const mentors = rows.map(r => {
      const first = (r.first_name || '').trim();
      const last = (r.last_name || '').trim();
      const name = (first || last) ? `${first} ${last}`.trim() : (r.username ? `@${r.username}` : 'User');

      let profession = '';
      let company = '';
      try {
        const exps = r.professional_experiences ? JSON.parse(r.professional_experiences) : [];
        if (Array.isArray(exps) && exps.length > 0) {
          const latest = exps[0];
          profession = (latest?.title || '').toString();
          company = (latest?.company || '').toString();
        }
      } catch {}

      let expertise = [];
      try {
        const ints = r.interest_domains ? JSON.parse(r.interest_domains) : [];
        if (Array.isArray(ints)) expertise = ints.map(String).slice(0, 10);
      } catch {}

      const ratingInfo = ratingMap[r.id] || {};
      const rating = ratingInfo.rating ? Number(ratingInfo.rating) : 5.0;
      const reviewCount = ratingInfo.reviewCount || 0;

      return {
        id: r.id,
        name,
        avatar: r.profile_photo_url || null,
        profession,
        company,
        expertise,
        rating,
        reviewCount,
        bio: r.bio || '',
        isOnline: false,
        location: '',
        yearsExperience: 0,
      };
    });

    return res.json(ok({ mentors }));
  } catch (e) {
    console.error('List mentors error:', e);
    return fail(res, 'internal_error', 500);
  }
});

// ---------- Sessions ----------
router.get('/sessions', async (req, res) => {
  try {
    const userId = req.user.id;
    const status = (req.query.status || 'upcoming').toString();

    let where = '';
    if (status === 'completed') where = "s.status = 'completed'";
    else if (status === 'cancelled') where = "s.status = 'cancelled'";
    else where = "s.status IN ('scheduled','in_progress')";

    const [rows] = await pool.execute(
      `SELECT 
         s.*,
         mp.first_name AS mentor_first_name, mp.last_name AS mentor_last_name, mp.username AS mentor_username, mp.profile_photo_url AS mentor_avatar
       FROM mentorship_sessions s
       LEFT JOIN profiles mp ON mp.user_id = s.mentor_user_id
       WHERE (${where}) AND (s.mentor_user_id = ? OR s.mentee_user_id = ?)
       ORDER BY s.scheduled_at ${status === 'completed' ? 'DESC' : 'ASC'}`,
      [userId, userId]
    );

    const sessions = rows.map(r => {
      const first = (r.mentor_first_name || '').trim();
      const last = (r.mentor_last_name || '').trim();
      const mentorName = (first || last) ? `${first} ${last}`.trim() : (r.mentor_username ? `@${r.mentor_username}` : 'Mentor');
      return {
        id: r.id,
        mentor_id: r.mentor_user_id,
        mentor_name: mentorName,
        mentor_avatar: r.mentor_avatar || null,
        scheduled_at: r.scheduled_at,
        duration_minutes: r.duration_minutes,
        topic: r.topic,
        status: r.status,
        meeting_link: r.meeting_link || null,
      };
    });

    return res.json(ok({ sessions }));
  } catch (e) {
    console.error('List sessions error:', e);
    return fail(res, 'internal_error', 500);
  }
});

router.post('/sessions', async (req, res) => {
  try {
    const userId = req.user.id;
    const schema = z.object({
      mentor_user_id: z.string(),
      scheduled_at: z.string(), // ISO
      duration_minutes: z.number().int().positive(),
      topic: z.string().min(1).max(500),
      meeting_link: z.string().url().optional(),
    });
    const body = schema.parse(req.body);

    const [rel] = await pool.execute(
      'SELECT id FROM mentorship_relations WHERE mentor_user_id = ? AND mentee_user_id = ? LIMIT 1',
      [body.mentor_user_id, userId]
    );
    if (rel.length === 0) {
      const rid = generateId();
      await pool.execute(
        'INSERT INTO mentorship_relations (id, mentor_user_id, mentee_user_id, created_at) VALUES (?, ?, ?, NOW())',
        [rid, body.mentor_user_id, userId]
      );
    }

    const id = generateId();
    await pool.execute(
      `INSERT INTO mentorship_sessions (id, mentor_user_id, mentee_user_id, scheduled_at, duration_minutes, topic, status, meeting_link, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, 'scheduled', ?, NOW(), NOW())`,
      [id, body.mentor_user_id, userId, body.scheduled_at, body.duration_minutes, body.topic, body.meeting_link || null]
    );

    return res.json(ok({ session: { id } }));
  } catch (e) {
    if (e instanceof z.ZodError) return fail(res, 'validation_error', 400, e.errors);
    console.error('Create session error:', e);
    return fail(res, 'internal_error', 500);
  }
});

router.patch('/sessions/:id/status', async (req, res) => {
  try {
    const userId = req.user.id;
    const schema = z.object({
      status: z.enum(['in_progress', 'completed', 'cancelled']),
    });
    const body = schema.parse(req.body);
    const { id } = req.params;

    const [rows] = await pool.execute(
      'SELECT * FROM mentorship_sessions WHERE id = ? AND (mentor_user_id = ? OR mentee_user_id = ?) LIMIT 1',
      [id, userId, userId]
    );
    if (rows.length === 0) return fail(res, 'session_not_found', 404);

    await pool.execute('UPDATE mentorship_sessions SET status = ?, updated_at = NOW() WHERE id = ?', [body.status, id]);
    return res.json(ok({ message: 'status_updated' }));
  } catch (e) {
    if (e instanceof z.ZodError) return fail(res, 'validation_error', 400, e.errors);
    console.error('Update session status error:', e);
    return fail(res, 'internal_error', 500);
  }
});

router.post('/sessions/:id/reviews', async (req, res) => {
  try {
    const userId = req.user.id;
    const schema = z.object({
      rating: z.number().int().min(1).max(5),
      comment: z.string().max(2000).optional(),
    });
    const body = schema.parse(req.body);
    const { id } = req.params;

    const [srows] = await pool.execute(
      'SELECT mentor_user_id, mentee_user_id FROM mentorship_sessions WHERE id = ? LIMIT 1',
      [id]
    );
    if (srows.length === 0) return fail(res, 'session_not_found', 404);

    const sess = srows[0];
    // Only the mentee can review the mentor for this session
    if (userId !== sess.mentee_user_id) {
      return fail(res, 'not_allowed', 403);
    }

    const reviewId = generateId();
    await pool.execute(
      `INSERT INTO mentorship_reviews (id, session_id, mentor_user_id, mentee_user_id, rating, comment, created_at)
       VALUES (?, ?, ?, ?, ?, ?, NOW())`,
      [reviewId, id, sess.mentor_user_id, userId, body.rating, body.comment || null]
    );

    return res.json(ok({ review: { id: reviewId } }));
  } catch (e) {
    if (e instanceof z.ZodError) return fail(res, 'validation_error', 400, e.errors);
    console.error('Create review error:', e);
    return fail(res, 'internal_error', 500);
  }
});

export default router;