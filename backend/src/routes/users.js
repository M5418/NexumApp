import express from 'express';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';

const router = express.Router();

// Get all users (excluding current user) for connections
router.get('/all', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT u.id, u.email,
              p.first_name, p.last_name, p.username,
              p.profile_photo_url, p.cover_photo_url, p.bio, p.status
       FROM users u
       LEFT JOIN profiles p ON p.user_id = u.id
       WHERE u.id != ?
       ORDER BY p.first_name, p.last_name, u.email`,
      [req.user.id]
    );

    // Transform data for frontend
    const users = rows.map(user => ({
      id: user.id,
      name: user.first_name && user.last_name 
        ? `${user.first_name} ${user.last_name}`.trim()
        : user.username || user.email || 'User',
      username: user.username ? `@${user.username}` : `@${user.email.split('@')[0]}`,
      email: user.email,
      avatarUrl: user.profile_photo_url || null,
      coverUrl: user.cover_photo_url || null,
      bio: user.bio || '',
      status: user.status || '',
      // Generate avatar letter from name
      avatarLetter: (user.first_name || user.username || user.email || 'U').charAt(0).toUpperCase()
    }));

    return res.json(ok(users));
  } catch (error) {
    console.error('Users fetch error:', error);
    return fail(res, 'internal_error', 500);
  }
});

export default router;
