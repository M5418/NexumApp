import express from 'express';
import { z } from 'zod';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';
import { generateId } from '../utils/id-generator.js';

const router = express.Router();

// Validation schemas
const sendInvitationSchema = z.object({
  receiver_id: z.string().min(1, 'Receiver ID is required'),
  invitation_content: z.string().min(1, 'Invitation content is required').max(1000, 'Content too long'),
});

const updateInvitationSchema = z.object({
  status: z.enum(['accepted', 'refused'], 'Status must be accepted or refused'),
});

// Helper function to update profile invitation counters
async function updateProfileCounters(userId) {
  try {
    const [sentCount] = await pool.execute(
      'SELECT COUNT(*) as count FROM invitations WHERE sender_id = ?',
      [userId]
    );
    
    const [receivedCount] = await pool.execute(
      'SELECT COUNT(*) as count FROM invitations WHERE receiver_id = ?',
      [userId]
    );
    
    const [acceptedCount] = await pool.execute(
      'SELECT COUNT(*) as count FROM invitations WHERE (sender_id = ? OR receiver_id = ?) AND status = "accepted"',
      [userId, userId]
    );
    
    const [refusedCount] = await pool.execute(
      'SELECT COUNT(*) as count FROM invitations WHERE (sender_id = ? OR receiver_id = ?) AND status = "refused"',
      [userId, userId]
    );
    
    const [pendingCount] = await pool.execute(
      'SELECT COUNT(*) as count FROM invitations WHERE (sender_id = ? OR receiver_id = ?) AND status = "pending"',
      [userId, userId]
    );

    await pool.execute(
      `UPDATE profiles SET 
        invitations_sent = ?, 
        invitations_received = ?, 
        invitations_accepted = ?, 
        invitations_refused = ?, 
        pending_invitations = ?
       WHERE user_id = ?`,
      [
        sentCount[0].count,
        receivedCount[0].count,
        acceptedCount[0].count,
        refusedCount[0].count,
        pendingCount[0].count,
        userId
      ]
    );
  } catch (error) {
    console.error('Error updating profile counters:', error);
  }
}

function normalizePair(a, b) {
  return a < b ? [a, b] : [b, a];
}

async function getOrCreateConversation(userA, userB) {
  const [a, b] = normalizePair(userA, userB);
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

// Get user's invitations (sent and received)
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;
    const type = req.query.type; // 'sent', 'received', or undefined for both

    let query = '';
    let params = [];

    if (type === 'sent') {
      query = `
        SELECT i.*, 
               p_receiver.first_name as receiver_first_name,
               p_receiver.last_name as receiver_last_name,
               p_receiver.username as receiver_username,
               p_receiver.profile_photo_url as receiver_avatar_url
        FROM invitations i
        LEFT JOIN profiles p_receiver ON p_receiver.user_id = i.receiver_id
        WHERE i.sender_id = ?
        ORDER BY i.created_at DESC
      `;
      params = [userId];
    } else if (type === 'received') {
      query = `
        SELECT i.*, 
               p_sender.first_name as sender_first_name,
               p_sender.last_name as sender_last_name,
               p_sender.username as sender_username,
               p_sender.profile_photo_url as sender_avatar_url
        FROM invitations i
        LEFT JOIN profiles p_sender ON p_sender.user_id = i.sender_id
        WHERE i.receiver_id = ?
        ORDER BY i.created_at DESC
      `;
      params = [userId];
    } else {
      query = `
        SELECT i.*, 
               p_sender.first_name as sender_first_name,
               p_sender.last_name as sender_last_name,
               p_sender.username as sender_username,
               p_sender.profile_photo_url as sender_avatar_url,
               p_receiver.first_name as receiver_first_name,
               p_receiver.last_name as receiver_last_name,
               p_receiver.username as receiver_username,
               p_receiver.profile_photo_url as receiver_avatar_url
        FROM invitations i
        LEFT JOIN profiles p_sender ON p_sender.user_id = i.sender_id
        LEFT JOIN profiles p_receiver ON p_receiver.user_id = i.receiver_id
        WHERE i.sender_id = ? OR i.receiver_id = ?
        ORDER BY i.created_at DESC
      `;
      params = [userId, userId];
    }

    const [rows] = await pool.execute(query, params);

    // Transform data for frontend
    const invitations = rows.map(row => ({
      id: row.id,
      sender_id: row.sender_id,
      receiver_id: row.receiver_id,
      invitation_content: row.invitation_content,
      status: row.status,
      created_at: row.created_at,
      updated_at: row.updated_at,
      sender: {
        name: row.sender_first_name && row.sender_last_name 
          ? `${row.sender_first_name} ${row.sender_last_name}`.trim()
          : row.sender_username || 'User',
        username: row.sender_username ? `@${row.sender_username}` : '@user',
        avatarUrl: row.sender_avatar_url || null,
      },
      receiver: {
        name: row.receiver_first_name && row.receiver_last_name 
          ? `${row.receiver_first_name} ${row.receiver_last_name}`.trim()
          : row.receiver_username || 'User',
        username: row.receiver_username ? `@${row.receiver_username}` : '@user',
        avatarUrl: row.receiver_avatar_url || null,
      },
      is_sender: row.sender_id === userId,
      is_receiver: row.receiver_id === userId,
    }));

    return res.json(ok({ invitations }));
  } catch (error) {
    console.error('Get invitations error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Send a new invitation
router.post('/', async (req, res) => {
  try {
    const senderId = req.user.id;
    const data = sendInvitationSchema.parse(req.body);

    // Check if receiver exists
    const [receiverExists] = await pool.execute(
      'SELECT id FROM users WHERE id = ?',
      [data.receiver_id]
    );

    if (receiverExists.length === 0) {
      return fail(res, 'receiver_not_found', 404);
    }

    // Prevent sending invitation to self
    if (senderId === data.receiver_id) {
      return fail(res, 'cannot_invite_self', 400);
    }

    // Check if there's already a pending invitation between these users
    const [existingInvitation] = await pool.execute(
      'SELECT id FROM invitations WHERE ((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)) AND status = "pending"',
      [senderId, data.receiver_id, data.receiver_id, senderId]
    );

    if (existingInvitation.length > 0) {
      return fail(res, 'invitation_already_exists', 409);
    }

    const invitationId = generateId();
    
    // Create the invitation
    await pool.execute(
      'INSERT INTO invitations (id, sender_id, receiver_id, invitation_content, status) VALUES (?, ?, ?, ?, "pending")',
      [invitationId, senderId, data.receiver_id, data.invitation_content]
    );

    // Update profile counters for both users
    await updateProfileCounters(senderId);
    await updateProfileCounters(data.receiver_id);

    // Get the created invitation with user details
    const [invitationRows] = await pool.execute(`
      SELECT i.*, 
             p_sender.first_name as sender_first_name,
             p_sender.last_name as sender_last_name,
             p_sender.username as sender_username,
             p_sender.profile_photo_url as sender_avatar_url,
             p_receiver.first_name as receiver_first_name,
             p_receiver.last_name as receiver_last_name,
             p_receiver.username as receiver_username,
             p_receiver.profile_photo_url as receiver_avatar_url
      FROM invitations i
      LEFT JOIN profiles p_sender ON p_sender.user_id = i.sender_id
      LEFT JOIN profiles p_receiver ON p_receiver.user_id = i.receiver_id
      WHERE i.id = ?
    `, [invitationId]);

    const invitation = invitationRows[0];
    const response = {
      id: invitation.id,
      sender_id: invitation.sender_id,
      receiver_id: invitation.receiver_id,
      invitation_content: invitation.invitation_content,
      status: invitation.status,
      created_at: invitation.created_at,
      sender: {
        name: invitation.sender_first_name && invitation.sender_last_name 
          ? `${invitation.sender_first_name} ${invitation.sender_last_name}`.trim()
          : invitation.sender_username || 'User',
        username: invitation.sender_username ? `@${invitation.sender_username}` : '@user',
        avatarUrl: invitation.sender_avatar_url || null,
      },
      receiver: {
        name: invitation.receiver_first_name && invitation.receiver_last_name 
          ? `${invitation.receiver_first_name} ${invitation.receiver_last_name}`.trim()
          : invitation.receiver_username || 'User',
        username: invitation.receiver_username ? `@${invitation.receiver_username}` : '@user',
        avatarUrl: invitation.receiver_avatar_url || null,
      },
    };

    return res.json(ok({ invitation: response }));
  } catch (error) {
    if (error instanceof z.ZodError) {
      return fail(res, 'validation_error', 400, error.errors);
    }
    console.error('Send invitation error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Update invitation status (accept/refuse)
router.put('/:invitationId', async (req, res) => {
  try {
    const userId = req.user.id;
    const { invitationId } = req.params;
    const data = updateInvitationSchema.parse(req.body);

    // Check if invitation exists and user is the receiver
    const [invitationRows] = await pool.execute(
      'SELECT * FROM invitations WHERE id = ? AND receiver_id = ? AND status = "pending"',
      [invitationId, userId]
    );

    if (invitationRows.length === 0) {
      return fail(res, 'invitation_not_found_or_not_authorized', 404);
    }

    const invitation = invitationRows[0];

    // Update invitation status
    await pool.execute(
      'UPDATE invitations SET status = ?, updated_at = NOW() WHERE id = ?',
      [data.status, invitationId]
    );

    // Update profile counters for both users
    await updateProfileCounters(invitation.sender_id);
    await updateProfileCounters(invitation.receiver_id);

    let conversationId = null;
    let initialMessageId = null;

    if (data.status === 'accepted') {
      // Create or find conversation
      conversationId = await getOrCreateConversation(invitation.sender_id, invitation.receiver_id);

      // Insert the invitation content as the first message from sender to receiver (text)
      const msgId = generateId();
      await pool.execute(
        `INSERT INTO chat_messages (id, conversation_id, sender_id, receiver_id, type, text, created_at, updated_at)
         VALUES (?, ?, ?, ?, 'text', ?, NOW(), NOW())`,
        [msgId, conversationId, invitation.sender_id, invitation.receiver_id, invitation.invitation_content]
      );
      initialMessageId = msgId;

      // Update conversation last message fields
      await pool.execute(
        `UPDATE conversations 
           SET last_message_type = 'text', last_message_text = ?, last_message_at = NOW(), updated_at = NOW()
         WHERE id = ?`,
        [invitation.invitation_content, conversationId]
      );
    }

    return res.json(ok({ 
      message: `Invitation ${data.status} successfully`,
      invitation_id: invitationId,
      status: data.status,
      conversation_id: conversationId,
      initial_message_id: initialMessageId,
    }));
  } catch (error) {
    if (error instanceof z.ZodError) {
      return fail(res, 'validation_error', 400, error.errors);
    }
    console.error('Update invitation error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Delete invitation (only sender can delete pending invitations)
router.delete('/:invitationId', async (req, res) => {
  try {
    const userId = req.user.id;
    const { invitationId } = req.params;

    // Check if invitation exists and user is the sender
    const [invitationRows] = await pool.execute(
      'SELECT * FROM invitations WHERE id = ? AND sender_id = ?',
      [invitationId, userId]
    );

    if (invitationRows.length === 0) {
      return fail(res, 'invitation_not_found_or_not_authorized', 404);
    }

    const invitation = invitationRows[0];

    // Delete the invitation
    await pool.execute('DELETE FROM invitations WHERE id = ?', [invitationId]);

    // Update profile counters for both users
    await updateProfileCounters(invitation.sender_id);
    await updateProfileCounters(invitation.receiver_id);

    return res.json(ok({ message: 'Invitation deleted successfully' }));
  } catch (error) {
    console.error('Delete invitation error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Get invitation statistics for a user
router.get('/stats', async (req, res) => {
  try {
    const userId = req.user.id;

    const [stats] = await pool.execute(`
      SELECT 
        (SELECT COUNT(*) FROM invitations WHERE sender_id = ?) as sent,
        (SELECT COUNT(*) FROM invitations WHERE receiver_id = ?) as received,
        (SELECT COUNT(*) FROM invitations WHERE (sender_id = ? OR receiver_id = ?) AND status = 'accepted') as accepted,
        (SELECT COUNT(*) FROM invitations WHERE (sender_id = ? OR receiver_id = ?) AND status = 'refused') as refused,
        (SELECT COUNT(*) FROM invitations WHERE (sender_id = ? OR receiver_id = ?) AND status = 'pending') as pending
    `, [userId, userId, userId, userId, userId, userId, userId, userId]);

    return res.json(ok({ stats: stats[0] }));
  } catch (error) {
    console.error('Get invitation stats error:', error);
    return fail(res, 'internal_error', 500);
  }
});

export default router;
