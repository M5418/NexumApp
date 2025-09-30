// File: backend/src/routes/kyc.js
// Lines: 1-240
import express from 'express';
import { z } from 'zod';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';
import { generateId } from '../utils/id-generator.js';

const router = express.Router();

const kycSchema = z.object({
  full_name: z.string().max(150).optional(),
  document_type: z.string().min(1).max(50),
  document_number: z.string().min(1).max(100),
  issue_place: z.string().max(100).optional(),
  issue_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),   // YYYY-MM-DD
  expiry_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),  // YYYY-MM-DD
  country: z.string().max(100).optional(),
  city_of_birth: z.string().max(100).optional(),
  address: z.string().max(255).optional(),
  uploaded_file_names: z.array(z.string().min(1).max(255)).optional(),
  front_url: z.string().url().optional(),
  back_url: z.string().url().optional(),
  selfie_url: z.string().url().optional(),
});

// Get current user's KYC (latest / only)
router.get('/me', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT
         id,
         user_id,
         full_name,
         document_type,
         document_number,
         issue_place,
         issue_date,
         expiry_date,
         country,
         city_of_birth,
         address,
         uploaded_file_names,
         front_url,
         back_url,
         selfie_url,
         status,
         is_approved,
         is_rejected,
         admin_notes,
         reviewed_by,
         reviewed_at,
         created_at,
         updated_at
       FROM kyc_verifications
       WHERE user_id = ?
       LIMIT 1`,
      [req.user.id]
    );

    if (!rows || rows.length === 0) {
      return res.json(ok(null));
    }

    const row = rows[0];
    if (row.uploaded_file_names) {
      try {
        row.uploaded_file_names = JSON.parse(row.uploaded_file_names);
      } catch {
        // leave as-is if parsing fails
      }
    }

    return res.json(ok(row));
  } catch (error) {
    console.error('KYC get error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Submit or update KYC for current user
router.post('/', async (req, res) => {
  try {
    const data = kycSchema.parse(req.body || {});
    const nowPending = {
      status: 'pending',
      is_approved: 0,
      is_rejected: 0,
      admin_notes: null,
      reviewed_by: null,
      reviewed_at: null,
    };

    // Does a KYC already exist for this user?
    const [existing] = await pool.execute(
      'SELECT id FROM kyc_verifications WHERE user_id = ? LIMIT 1',
      [req.user.id]
    );

    if (!existing || existing.length === 0) {
      const id = generateId();
      const sql = `INSERT INTO kyc_verifications (
        id, user_id, full_name, document_type, document_number, issue_place,
        issue_date, expiry_date, country, city_of_birth, address,
        uploaded_file_names, front_url, back_url, selfie_url,
        status, is_approved, is_rejected,
        admin_notes, reviewed_by, reviewed_at
      ) VALUES (
        ?, ?, ?, ?, ?, ?,
        ?, ?, ?, ?, ?,
        ?, ?, ?, ?,
        ?, ?, ?,
        ?, ?, ?
      )`;

      const values = [
        id,
        req.user.id,
        data.full_name ?? null,
        data.document_type,
        data.document_number,
        data.issue_place ?? null,
        data.issue_date ?? null,
        data.expiry_date ?? null,
        data.country ?? null,
        data.city_of_birth ?? null,
        data.address ?? null,
        data.uploaded_file_names ? JSON.stringify(data.uploaded_file_names) : null,
        data.front_url ?? null,
        data.back_url ?? null,
        data.selfie_url ?? null,
        nowPending.status,
        nowPending.is_approved,
        nowPending.is_rejected,
        nowPending.admin_notes,
        nowPending.reviewed_by,
        nowPending.reviewed_at,
      ];

      await pool.execute(sql, values);
      return res.json(ok({ id, status: 'pending' }));
    }

    // Update existing record
    const kycId = existing[0].id;
    const sql = `UPDATE kyc_verifications
      SET full_name = ?,
          document_type = ?,
          document_number = ?,
          issue_place = ?,
          issue_date = ?,
          expiry_date = ?,
          country = ?,
          city_of_birth = ?,
          address = ?,
          uploaded_file_names = ?,
          front_url = ?,
          back_url = ?,
          selfie_url = ?,
          status = ?,
          is_approved = ?,
          is_rejected = ?,
          admin_notes = ?,
          reviewed_by = ?,
          reviewed_at = ?
      WHERE user_id = ?
      LIMIT 1`;

    const values = [
      data.full_name ?? null,
      data.document_type,
      data.document_number,
      data.issue_place ?? null,
      data.issue_date ?? null,
      data.expiry_date ?? null,
      data.country ?? null,
      data.city_of_birth ?? null,
      data.address ?? null,
      data.uploaded_file_names ? JSON.stringify(data.uploaded_file_names) : null,
      data.front_url ?? null,
      data.back_url ?? null,
      data.selfie_url ?? null,
      nowPending.status,
      nowPending.is_approved,
      nowPending.is_rejected,
      nowPending.admin_notes,
      nowPending.reviewed_by,
      nowPending.reviewed_at,
      req.user.id,
    ];

    await pool.execute(sql, values);
    return res.json(ok({ id: kycId, status: 'pending' }));
  } catch (error) {
    if (error instanceof z.ZodError) {
      return fail(res, 'validation_error', 400);
    }
    console.error('KYC submit error:', error);
    return fail(res, 'internal_error', 500);
  }
});

export default router;