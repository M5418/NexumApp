import express from 'express';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';

const router = express.Router();

// Get all users (excluding current user) for connections
router.get('/all', async (req, res) => {
  try {
    console.log(`🔍 Fetching all users for user ID: ${req.user.id}`);
    
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

    console.log(`🔍 Found ${rows.length} users in database`);

    // Transform data for frontend with robust fallbacks
    const users = rows.map(user => {
      const firstName = user.first_name?.trim() || '';
      const lastName = user.last_name?.trim() || '';
      const username = user.username?.trim() || '';
      const email = user.email?.trim() || '';
      
      // Generate name with multiple fallbacks
      let name = '';
      if (firstName && lastName) {
        name = `${firstName} ${lastName}`;
      } else if (firstName) {
        name = firstName;
      } else if (lastName) {
        name = lastName;
      } else if (username) {
        name = username;
      } else if (email) {
        name = email.split('@')[0];
      } else {
        name = 'User';
      }

      // Generate username with fallbacks
      let displayUsername = '';
      if (username) {
        displayUsername = `@${username}`;
      } else if (email) {
        displayUsername = `@${email.split('@')[0]}`;
      } else {
        displayUsername = '@user';
      }

      // Generate avatar letter
      const avatarLetter = (firstName || username || email || 'U').charAt(0).toUpperCase();

      return {
        id: user.id,
        name: name,
        username: displayUsername,
        email: email,
        avatarUrl: user.profile_photo_url || null,
        coverUrl: user.cover_photo_url || null,
        bio: user.bio || '',
        status: user.status || '',
        avatarLetter: avatarLetter
      };
    });

    console.log(`🔍 Transformed users:`, users.map(u => ({ id: u.id, name: u.name, username: u.username })));

    return res.json(ok(users));
  } catch (error) {
    console.error('❌ Users fetch error:', error);
    return fail(res, 'internal_error', 500);
  }
});

export default router;
