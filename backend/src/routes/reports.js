// File: backend/src/routes/reports.js
import express from 'express';
import { z } from 'zod';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';
import { generateId } from '../utils/id-generator.js';
import adminOnly from '../middleware/admin.js';

const router = express.Router();

const createSchema = z.object({
  targetType: z.enum(['post', 'story', 'user']),
  targetId: z.string().min(1),
  cause: z.string().min(1).max(64),
  comment: z.string().max(1000).optional().nullable(),
});

const listSchema = z.object({
  status: z.enum(['pending', 'approved', 'rejected', 'ignored']).optional(),
  targetType: z.enum(['post', 'story', 'user']).optional(),
  limit: z.coerce.number().min(1).max(200).default(50),
  offset: z.coerce.number().min(0).default(0),
});

const decisionSchema = z.object({
  status: z.enum(['approved', 'rejected', 'ignored']),
  decisionText: z.string().max(2000).optional().nullable(),
});

// Utility: get full_name and username for a user
async function getProfileNameUsername(userId) {
  const [rows] = await pool.execute(
    'SELECT first_name, last_name, username FROM profiles WHERE user_id = ?',
    [userId]
  );
  if (rows.length === 0) return { fullName: '', username: '' };
  const p = rows[0];
  const first = (p.first_name || '').trim();
  const last = (p.last_name || '').trim();
  const fullName = [first, last].filter(Boolean).join(' ').trim();
  const username = (p.username || '').trim();
  return { fullName, username };
}

// Utility: fetch owner user_id for a post or story
async function getTargetOwnerUserId(targetType, targetId) {
  if (targetType === 'user') return targetId;
  if (targetType === 'post') {
    const [rows] = await pool.execute('SELECT user_id FROM posts WHERE id = ?', [targetId]);
    return rows.length ? String(rows[0].user_id) : null;
  }
  if (targetType === 'story') {
    const [rows] = await pool.execute('SELECT user_id FROM stories WHERE id = ?', [targetId]);
    return rows.length ? String(rows[0].user_id) : null;
  }
  return null;
}

// POST /api/reports
router.post('/', async (req, res) => {
  try {
    const { targetType, targetId, cause, comment } = createSchema.parse(req.body);
    const reporterId = req.user.id;

    // Validate the target exists (best effort)
    const targetOwnerUserId = await getTargetOwnerUserId(targetType, targetId);
    if (!targetOwnerUserId) return fail(res, 'target_not_found', 404);

    const reporterInfo = await getProfileNameUsername(reporterId);
    const targetInfo = await getProfileNameUsername(targetOwnerUserId);

    const id = generateId();
    await pool.execute(
      `INSERT INTO reports
       (id, reporter_user_id, target_type, target_id, target_owner_user_id, cause, description,
        reporter_full_name, reporter_username, target_full_name, target_username, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
      [
        id,
        reporterId,
        targetType,
        targetId,
        targetOwnerUserId,
        cause,
        comment || null,
        reporterInfo.fullName || null,
        reporterInfo.username || null,
        targetInfo.fullName || null,
        targetInfo.username || null,
      ]
    );

    return res.json(ok({ id }));
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Create report error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// GET /api/reports (admin)
router.get('/', adminOnly, async (req, res) => {
  try {
    const p = listSchema.parse(req.query);
    const where = [];
    const params = [];
    if (p.status) { where.push('status = ?'); params.push(p.status); }
    if (p.targetType) { where.push('target_type = ?'); params.push(p.targetType); }
    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const limit = p.limit;
    const offset = p.offset;
    const [rows] = await pool.execute(
      `SELECT * FROM reports ${whereSql} ORDER BY created_at DESC LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );
    return res.json(ok({ reports: rows }));
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('List reports error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// GET /api/reports/:id (admin)
router.get('/:id', adminOnly, async (req, res) => {
  try {
    const [rows] = await pool.execute('SELECT * FROM reports WHERE id = ?', [req.params.id]);
    if (rows.length === 0) return fail(res, 'not_found', 404);
    return res.json(ok({ report: rows[0] }));
  } catch (error) {
    console.error('Get report error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// PATCH /api/reports/:id (admin decision)
router.patch('/:id', adminOnly, async (req, res) => {
  try {
    const { status, decisionText } = decisionSchema.parse(req.body);
    const adminUserId = req.user.id;

    const [result] = await pool.execute(
      `UPDATE reports
       SET status = ?, admin_user_id = ?, admin_decision_text = ?, decided_at = NOW()
       WHERE id = ?`,
      [status, adminUserId, decisionText || null, req.params.id]
    );

    if (result.affectedRows === 0) return fail(res, 'not_found', 404);
    return res.json(ok({}));
  } catch (error) {
    if (error instanceof z.ZodError) return fail(res, 'validation_error', 400);
    console.error('Decision error:', error);
    return fail(res, 'internal_error', 500);
  }
});

export default router;