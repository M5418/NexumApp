import express from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';
import { generateUserId } from '../utils/id-generator.js';
import authMiddleware from '../middleware/auth.js';
import { sendEmail } from '../utils/mailer.js';
import { generateFiveDigitCode } from '../utils/code-generator.js';

const router = express.Router();

// Validation schemas
const signupSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const changePasswordRequestSchema = z.object({
  current_password: z.string().min(1),
  new_password: z.string().min(8),
});

const changePasswordVerifySchema = z.object({
  code: z.string().regex(/^\d{5}$/),
});

const changeEmailRequestSchema = z.object({
  current_password: z.string().min(1),
  new_email: z.string().email(),
});

const changeEmailVerifySchema = z.object({
  code: z.string().regex(/^\d{5}$/),
});

// Helpers
async function clearPending(conn, userId, purpose) {
  await conn.execute(
    'DELETE FROM auth_verification_codes WHERE user_id = ? AND purpose = ? AND consumed = 0',
    [userId, purpose]
  );
}

function expiresInMinutes(mins = 10) {
  return mins;
}

// POST /api/auth/signup
router.post('/signup', async (req, res) => {
  try {
    const { email, password } = signupSchema.parse(req.body);

    const [existing] = await pool.execute(
      'SELECT id FROM users WHERE email = ?',
      [email]
    );
    if (existing.length > 0) return fail(res, 'email_already_exists', 409);

    const userId = generateUserId();
    const passwordHash = await bcrypt.hash(password, 12);

    await pool.execute(
      'INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)',
      [userId, email, passwordHash]
    );

    const token = jwt.sign({ sub: userId, email }, process.env.JWT_SECRET, { expiresIn: '7d' });

    res.json(ok({ token, user: { id: userId, email } }));
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Signup error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// POST /api/auth/login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = loginSchema.parse(req.body);

    const [users] = await pool.execute(
      'SELECT id, email, password_hash FROM users WHERE email = ?',
      [email]
    );
    if (users.length === 0) return fail(res, 'invalid_credentials', 401);

    const user = users[0];
    const isValid = await bcrypt.compare(password, user.password_hash);
    if (!isValid) return fail(res, 'invalid_credentials', 401);

    const token = jwt.sign({ sub: user.id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '7d' });

    res.json(ok({ token, user: { id: user.id, email: user.email } }));
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Login error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// GET /api/auth/me (fetch from DB to reflect current email)
router.get('/me', authMiddleware, async (req, res) => {
  try {
    const [rows] = await pool.execute('SELECT id, email FROM users WHERE id = ?', [req.user.id]);
    if (rows.length === 0) return fail(res, 'unauthorized', 401);
    res.json(ok({ id: rows[0].id, email: rows[0].email }));
  } catch (error) {
    console.error('Me error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// POST /api/auth/logout
router.post('/logout', (req, res) => res.json(ok({})));

/**
 * CHANGE PASSWORD: request -> verify
 */

// PATCH /api/auth/change-password (REQUEST)
router.patch('/change-password', authMiddleware, async (req, res) => {
  try {
    const { current_password, new_password } = changePasswordRequestSchema.parse(req.body);
    const userId = req.user.id;

    const conn = await pool.getConnection();
    try {
      const [rows] = await conn.execute('SELECT id, email, password_hash FROM users WHERE id = ?', [userId]);
      if (rows.length === 0) { conn.release(); return fail(res, 'not_found', 404); }
      const user = rows[0];

      const valid = await bcrypt.compare(current_password, user.password_hash);
      if (!valid) { conn.release(); return fail(res, 'invalid_current_password', 401); }

      const newHash = await bcrypt.hash(new_password, 12);
      const code = generateFiveDigitCode();
      const id = generateUserId();
      const ttlMins = expiresInMinutes(10);

      await conn.beginTransaction();
      await clearPending(conn, userId, 'change_password');

      await conn.execute(
        `INSERT INTO auth_verification_codes
          (id, user_id, purpose, code, sent_to, new_password_hash, expires_at)
         VALUES (?, ?, 'change_password', ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))`,
        [id, userId, code, user.email, newHash, ttlMins]
      );

      await conn.commit();
      conn.release();

      await sendEmail({
        to: user.email,
        subject: 'Nexum: Confirm Password Change',
        text:
`Hi,

You requested to change your Nexum password.
Please enter this 5-digit code to confirm:

  ${code}

This code expires in ${ttlMins} minutes.

If you did not request this, please ignore this email or contact support.

– Nexum Team`
      });

      return res.json(ok({ sent_to: user.email }));
    } catch (e) {
      try { await conn.rollback(); } catch (_) {}
      conn.release();
      console.error('Change password request error:', e);
      return fail(res, 'internal_error', 500);
    }
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Change password request error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// POST /api/auth/change-password/verify (VERIFY)
router.post('/change-password/verify', authMiddleware, async (req, res) => {
  try {
    const { code } = changePasswordVerifySchema.parse(req.body);
    const userId = req.user.id;

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      const [rows] = await conn.execute(
        `SELECT * FROM auth_verification_codes
         WHERE user_id = ? AND purpose = 'change_password' AND code = ? AND consumed = 0 AND expires_at > NOW()
         ORDER BY created_at DESC
         LIMIT 1`,
        [userId, code]
      );

      if (rows.length === 0) {
        await conn.commit();
        conn.release();
        return fail(res, 'invalid_or_expired_code', 400);
      }

      const rec = rows[0];
      if (!rec.new_password_hash) {
        await conn.commit();
        conn.release();
        return fail(res, 'invalid_request_state', 400);
      }

      await conn.execute('UPDATE users SET password_hash = ? WHERE id = ?', [rec.new_password_hash, userId]);
      await conn.execute('UPDATE auth_verification_codes SET consumed = 1 WHERE id = ?', [rec.id]);

      await conn.commit();
      conn.release();

      await sendEmail({
        to: rec.sent_to,
        subject: 'Nexum: Password Changed',
        text:
`Hi,

Your Nexum password has been changed successfully.

If you did not perform this action, contact support immediately.

– Nexum Team`
      });

      return res.json(ok({}));
    } catch (e) {
      try { await conn.rollback(); } catch (_) {}
      conn.release();
      console.error('Change password verify error:', e);
      return fail(res, 'internal_error', 500);
    }
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Change password verify error:', error);
    return fail(res, 'internal_error', 500);
  }
});

/**
 * CHANGE EMAIL: request -> verify
 */

// PATCH /api/auth/change-email (REQUEST)
router.patch('/change-email', authMiddleware, async (req, res) => {
  try {
    const { current_password, new_email } = changeEmailRequestSchema.parse(req.body);
    const userId = req.user.id;

    const conn = await pool.getConnection();
    try {
      const [rows] = await conn.execute('SELECT id, email, password_hash FROM users WHERE id = ?', [userId]);
      if (rows.length === 0) { conn.release(); return fail(res, 'not_found', 404); }
      const user = rows[0];

      const valid = await bcrypt.compare(current_password, user.password_hash);
      if (!valid) { conn.release(); return fail(res, 'invalid_current_password', 401); }

      if (new_email.toLowerCase() === String(user.email).toLowerCase()) {
        conn.release();
        return fail(res, 'same_email', 400);
      }

      const [dupe] = await conn.execute('SELECT id FROM users WHERE email = ? AND id <> ?', [new_email, userId]);
      if (dupe.length > 0) { conn.release(); return fail(res, 'email_already_exists', 409); }

      const code = generateFiveDigitCode();
      const id = generateUserId();
      const ttlMins = expiresInMinutes(10);

      await conn.beginTransaction();
      await clearPending(conn, userId, 'change_email');

      await conn.execute(
        `INSERT INTO auth_verification_codes
          (id, user_id, purpose, code, sent_to, new_email, expires_at)
         VALUES (?, ?, 'change_email', ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))`,
        [id, userId, code, user.email, new_email, ttlMins]
      );

      await conn.commit();
      conn.release();

      await sendEmail({
        to: user.email,
        subject: 'Nexum: Confirm Email Change',
        text:
`Hi,

You requested to change your Nexum account email to: ${new_email}
Please enter this 5-digit code to confirm:

  ${code}

This code expires in ${ttlMins} minutes.

If you did not request this, please ignore this email or contact support.

– Nexum Team`
      });

      return res.json(ok({ sent_to: user.email }));
    } catch (e) {
      try { await conn.rollback(); } catch (_) {}
      conn.release();
      console.error('Change email request error:', e);
      return fail(res, 'internal_error', 500);
    }
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Change email request error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// POST /api/auth/change-email/verify (VERIFY)
router.post('/change-email/verify', authMiddleware, async (req, res) => {
  try {
    const { code } = changeEmailVerifySchema.parse(req.body);
    const userId = req.user.id;

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      const [rows] = await conn.execute(
        `SELECT * FROM auth_verification_codes
         WHERE user_id = ? AND purpose = 'change_email' AND code = ? AND consumed = 0 AND expires_at > NOW()
         ORDER BY created_at DESC
         LIMIT 1`,
        [userId, code]
      );

      if (rows.length === 0) {
        await conn.commit();
        conn.release();
        return fail(res, 'invalid_or_expired_code', 400);
      }

      const rec = rows[0];
      const newEmail = rec.new_email;
      if (!newEmail) {
        await conn.commit();
        conn.release();
        return fail(res, 'invalid_request_state', 400);
      }

      const [dupe] = await conn.execute('SELECT id FROM users WHERE email = ? AND id <> ?', [newEmail, userId]);
      if (dupe.length > 0) {
        await conn.commit();
        conn.release();
        return fail(res, 'email_already_exists', 409);
      }

      await conn.execute('UPDATE users SET email = ? WHERE id = ?', [newEmail, userId]);
      await conn.execute('UPDATE auth_verification_codes SET consumed = 1 WHERE id = ?', [rec.id]);

      await conn.commit();
      conn.release();

      await sendEmail({
        to: rec.sent_to,
        subject: 'Nexum: Email Changed',
        text:
`Hi,

The email on your Nexum account has been changed to: ${newEmail}

If you did not perform this action, contact support immediately.

– Nexum Team`
      });
      await sendEmail({
        to: newEmail,
        subject: 'Nexum: Email Updated',
        text:
`Hi,

This address is now associated with your Nexum account. Welcome!

If you did not perform this action, contact support immediately.

– Nexum Team`
      });

      return res.json(ok({ email: newEmail }));
    } catch (e) {
      try { await conn.rollback(); } catch (_) {}
      conn.release();
      console.error('Change email verify error:', e);
      return fail(res, 'internal_error', 500);
    }
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Change email verify error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// DELETE /api/auth/delete-account
router.delete('/delete-account', authMiddleware, async (req, res) => {
  const userId = req.user.id;

  const safeExec = async (conn, sql, params) => {
    try { await conn.execute(sql, params); }
    catch (e) { console.error('Delete step failed:', e.code || e.message, sql); }
  };

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    await safeExec(conn, 'DELETE FROM notifications WHERE user_id = ? OR actor_id = ? OR other_user_id = ?', [userId, userId, userId]);
    await safeExec(conn, 'DELETE FROM notifications WHERE post_id IN (SELECT id FROM posts WHERE user_id = ?)', [userId]);
    await safeExec(conn, 'DELETE FROM notifications WHERE community_post_id IN (SELECT id FROM community_posts WHERE user_id = ?)', [userId]);

    await safeExec(conn, 'DELETE FROM story_views WHERE viewer_id = ?', [userId]);
    await safeExec(conn, 'DELETE FROM story_mutes WHERE muter_id = ? OR target_user_id = ?', [userId, userId]);
    await safeExec(conn, 'DELETE FROM stories WHERE user_id = ?', [userId]);

    await safeExec(conn, 'DELETE FROM community_post_comment_replies WHERE user_id = ?', [userId]);
    await safeExec(conn, 'DELETE FROM community_post_comments WHERE user_id = ?', [userId]);
    await safeExec(conn, 'DELETE FROM community_post_reposts WHERE reposted_by_user_id = ?', [userId]);
    await safeExec(conn, 'DELETE FROM community_posts WHERE user_id = ?', [userId]);

    await safeExec(conn, 'DELETE FROM post_comments WHERE user_id = ?', [userId]);
    await safeExec(conn, 'DELETE FROM posts WHERE user_id = ?', [userId]);

    await safeExec(conn, 'DELETE FROM book_favorites WHERE user_id = ?', [userId]);
    await safeExec(conn, 'DELETE FROM book_progress WHERE user_id = ?', [userId]);
    await safeExec(conn, 'DELETE FROM books WHERE created_by_user_id = ?', [userId]);

    await safeExec(conn, 'DELETE FROM podcast_favorites WHERE user_id = ?', [userId]);
    await safeExec(conn, 'DELETE FROM podcast_progress WHERE user_id = ?', [userId]);
    await safeExec(conn, 'DELETE FROM playlists WHERE user_id = ?', [userId]);
    await safeExec(conn, 'DELETE FROM podcasts WHERE created_by_user_id = ?', [userId]);

    await safeExec(conn, 'DELETE FROM invitations WHERE sender_id = ? OR receiver_id = ?', [userId, userId]);

    await safeExec(conn, 'DELETE FROM connections WHERE from_user_id = ? OR to_user_id = ?', [userId, userId]);

    await safeExec(conn, 'DELETE FROM conversations WHERE user_a_id = ? OR user_b_id = ?', [userId, userId]);

    await safeExec(conn, 'DELETE FROM mentorship_reviews WHERE mentor_user_id = ? OR mentee_user_id = ?', [userId, userId]);
    await safeExec(conn, 'DELETE FROM mentorship_sessions WHERE mentor_user_id = ? OR mentee_user_id = ?', [userId, userId]);
    await safeExec(conn, 'DELETE FROM mentorship_requests WHERE requester_user_id = ?', [userId]);
    await safeExec(conn, 'DELETE FROM mentorship_conversations WHERE mentor_user_id = ? OR mentee_user_id = ?', [userId, userId]);
    await safeExec(conn, 'DELETE FROM mentorship_relations WHERE mentor_user_id = ? OR mentee_user_id = ?', [userId, userId]);

    await safeExec(conn, 'DELETE FROM uploads WHERE user_id = ?', [userId]);

    await safeExec(conn, 'DELETE FROM profiles WHERE user_id = ?', [userId]);

    await safeExec(conn, 'DELETE FROM auth_verification_codes WHERE user_id = ?', [userId]);

    await safeExec(conn, 'DELETE FROM users WHERE id = ?', [userId]);

    await conn.commit();
    return res.json(ok({}));
  } catch (e) {
    await conn.rollback();
    console.error('Delete account error:', e);
    return fail(res, 'internal_error', 500);
  } finally {
    conn.release();
  }
});

export default router;