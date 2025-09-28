// backend/src/utils/notifications.js
import pool from '../db/db.js';
import { generateId } from './id-generator.js';

/**
 * Create a notification row.
 * Only provide the fields relevant for the given 'type'.
 *
 * @param {{
 *  user_id: string,
 *  actor_id?: string|null,
 *  type: 'post_created'|'community_post_created'|'connection_received'|'post_liked'|'comment_added'|'comment_liked'|'community_post_liked'|'community_comment_added'|'community_comment_liked'|'invitation_received'|'invitation_accepted'|'post_tagged'|'community_post_tagged',
 *  post_id?: string|null,
 *  community_post_id?: string|null,
 *  community_id?: string|null,
 *  post_comment_id?: string|null,
 *  community_comment_id?: string|null,
 *  invitation_id?: string|null,
 *  conversation_id?: string|null,
 *  other_user_id?: string|null,
 *  preview_text?: string|null,
 *  preview_image_url?: string|null,
 * }} payload
 * @returns {Promise<string>} notification id
 */
export async function createNotification(payload) {
  const id = generateId();

  const {
    user_id,
    actor_id = null,
    type,
    post_id = null,
    community_post_id = null,
    community_id = null,
    post_comment_id = null,
    community_comment_id = null,
    invitation_id = null,
    conversation_id = null,
    other_user_id = null,
    preview_text = null,
    preview_image_url = null,
  } = payload || {};

  if (!user_id || !type) {
    throw new Error('createNotification: user_id and type are required');
  }

  await pool.execute(
    `INSERT INTO notifications
      (id, user_id, actor_id, type, post_id, community_post_id, community_id, post_comment_id, community_comment_id, invitation_id, conversation_id, other_user_id, preview_text, preview_image_url, is_read, created_at, updated_at)
     VALUES
      (?,  ?,      ?,        ?,    ?,       ?,                ?,            ?,                ?,                    ?,             ?,               ?,             ?,             ?,                  0,      NOW(),     NOW())`,
    [
      id,
      user_id,
      actor_id,
      type,
      post_id,
      community_post_id,
      community_id,
      post_comment_id,
      community_comment_id,
      invitation_id,
      conversation_id,
      other_user_id,
      preview_text,
      preview_image_url,
    ]
  );

  return id;
}