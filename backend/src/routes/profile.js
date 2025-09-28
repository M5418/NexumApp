import express from 'express';
import { z } from 'zod';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';
import { generateId } from '../utils/id-generator.js';

const router = express.Router();

const experienceSchema = z.object({
  title: z.string().min(1).max(200)
});

const trainingSchema = z.object({
  title: z.string().min(1).max(200),
  subtitle: z.string().min(1).max(200).optional()
});

const profileSchema = z.object({
  first_name: z.string().min(1).max(100).optional(),
  last_name: z.string().min(1).max(100).optional(),
  username: z.string().min(3).max(100).optional(),
  birthday: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  gender: z.string().max(50).optional(),
  professional_experiences: z.array(experienceSchema).max(20).optional(),
  trainings: z.array(trainingSchema).max(20).optional(),
  bio: z.string().max(1000).optional(),
  status: z.string().max(50).optional(),
  interest_domains: z.array(z.string()).max(50).optional(),
  street: z.string().max(255).optional(),
  city: z.string().max(100).optional(),
  state: z.string().max(100).optional(),
  postal_code: z.string().max(20).optional(),
  country: z.string().max(100).optional(),
  profile_photo_url: z.string().url().optional(),
  cover_photo_url: z.string().url().optional()
});

// Get current user's profile
router.get('/me', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT 
          u.id AS user_id,
          u.email,
          p.first_name,
          p.last_name,
          p.username,
          p.birthday,
          p.gender,
          p.professional_experiences,
          p.trainings,
          p.bio,
          p.status,
          p.interest_domains,
          p.street,
          p.city,
          p.state,
          p.postal_code,
          p.country,
          p.profile_photo_url,
          p.cover_photo_url,
          p.created_at AS profile_created_at,
          p.updated_at AS profile_updated_at,
          -- Convenience: computed full name
          TRIM(CONCAT(COALESCE(p.first_name, ''), ' ', COALESCE(p.last_name, ''))) AS full_name,
          -- Connection counts
          (
            SELECT COUNT(*) FROM connections c
             WHERE c.from_user_id = u.id
          ) AS connections_outbound_count,
          (
            SELECT COUNT(*) FROM connections c
             WHERE c.to_user_id = u.id
          ) AS connections_inbound_count,
          (
            SELECT COUNT(DISTINCT 
                     CASE 
                       WHEN c.from_user_id = u.id THEN c.to_user_id 
                       ELSE c.from_user_id 
                     END)
              FROM connections c
             WHERE c.from_user_id = u.id OR c.to_user_id = u.id
          ) AS connections_total_count
       FROM users u
       LEFT JOIN profiles p ON p.user_id = u.id
       WHERE u.id = ?
       LIMIT 1`,
      [req.user.id]
    );

    if (!rows || rows.length === 0) {
      return res.json(ok({ user_id: req.user.id }));
    }

    return res.json(ok(rows[0]));
  } catch (error) {
    console.error('Profile get error:', error);
    return fail(res, 'internal_error', 500);
  }
});
// Get another user's profile by ID
router.get('/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const [rows] = await pool.execute(
      `SELECT 
          u.id AS user_id,
          u.email,
          p.first_name,
          p.last_name,
          p.username,
          p.birthday,
          p.gender,
          p.professional_experiences,
          p.trainings,
          p.bio,
          p.status,
          p.interest_domains,
          p.street,
          p.city,
          p.state,
          p.postal_code,
          p.country,
          p.profile_photo_url,
          p.cover_photo_url,
          p.created_at AS profile_created_at,
          p.updated_at AS profile_updated_at,
          TRIM(CONCAT(COALESCE(p.first_name, ''), ' ', COALESCE(p.last_name, ''))) AS full_name,
          (
            SELECT COUNT(*) FROM connections c
             WHERE c.from_user_id = u.id
          ) AS connections_outbound_count,
          (
            SELECT COUNT(*) FROM connections c
             WHERE c.to_user_id = u.id
          ) AS connections_inbound_count,
          (
            SELECT COUNT(DISTINCT 
                     CASE 
                       WHEN c.from_user_id = u.id THEN c.to_user_id 
                       ELSE c.from_user_id 
                     END)
              FROM connections c
             WHERE c.from_user_id = u.id OR c.to_user_id = u.id
          ) AS connections_total_count
       FROM users u
       LEFT JOIN profiles p ON p.user_id = u.id
       WHERE u.id = ?
       LIMIT 1`,
      [userId]
    );

    if (!rows || rows.length === 0) {
      return res.json(ok({ user_id: userId }));
    }

    return res.json(ok(rows[0]));
  } catch (error) {
    console.error('Profile get by id error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Upsert current user's profile
router.patch('/', async (req, res) => {
  try {
    const data = profileSchema.parse(req.body || {});
    const fields = Object.keys(data);

    if (fields.length === 0) {
      return fail(res, 'no_fields', 400);
    }

    // Check if profile exists
    const [existingProfile] = await pool.execute(
      'SELECT id FROM profiles WHERE user_id = ?',
      [req.user.id]
    );

    if (existingProfile.length === 0) {
      // Create new profile with custom ID
      const profileId = generateId();
      const cols = ['id', 'user_id', ...fields];
      const placeholders = Array(cols.length).fill('?').join(',');
      const values = [
        profileId,
        req.user.id,
        ...fields.map((f) => {
          if (['professional_experiences', 'trainings', 'interest_domains'].includes(f) && data[f] != null) {
            return JSON.stringify(data[f]);
          }
          return data[f];
        }),
      ];

      const sql = `INSERT INTO profiles (${cols.join(',')}) VALUES (${placeholders})`;
      await pool.execute(sql, values);
    } else {
      // Update existing profile
      const updates = fields.map((f) => `${f} = ?`).join(', ');
      const values = [
        ...fields.map((f) => {
          if (['professional_experiences', 'trainings', 'interest_domains'].includes(f) && data[f] != null) {
            return JSON.stringify(data[f]);
          }
          return data[f];
        }),
        req.user.id
      ];

      const sql = `UPDATE profiles SET ${updates} WHERE user_id = ?`;
      await pool.execute(sql, values);
    }

    return res.json(ok({}));
  } catch (error) {
    if (error instanceof z.ZodError) {
      return fail(res, 'validation_error', 400);
    }
    // Handle duplicate username
    if (error && error.code === 'ER_DUP_ENTRY') {
      return fail(res, 'username_taken', 409);
    }
    console.error('Profile upsert error:', error);
    return fail(res, 'internal_error', 500);
  }
});

export default router;