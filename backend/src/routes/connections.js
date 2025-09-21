import express from 'express';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';

const router = express.Router();

// List inbound and outbound connections for the authenticated user
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;

    const [outRows] = await pool.execute(
      'SELECT to_user_id FROM connections WHERE from_user_id = ? ORDER BY created_at DESC',
      [userId]
    );
    const [inRows] = await pool.execute(
      'SELECT from_user_id FROM connections WHERE to_user_id = ? ORDER BY created_at DESC',
      [userId]
    );

    const outbound = outRows.map(r => Number(r.to_user_id));
    const inbound = inRows.map(r => Number(r.from_user_id));

    return res.json(ok({ inbound, outbound }));
  } catch (error) {
    console.error('Connections list error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Create a connection from the authenticated user to :userId
router.post('/:userId', async (req, res) => {
  try {
    const fromUserId = req.user.id;
    const toUserId = Number(req.params.userId);

    if (!toUserId || toUserId === fromUserId) {
      return fail(res, 'invalid_user_id', 400);
    }

    await pool.execute(
      'INSERT IGNORE INTO connections (from_user_id, to_user_id) VALUES (?, ?)',
      [fromUserId, toUserId]
    );

    return res.json(ok({}));
  } catch (error) {
    console.error('Connect error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Remove a connection from the authenticated user to :userId
router.delete('/:userId', async (req, res) => {
  try {
    const fromUserId = req.user.id;
    const toUserId = Number(req.params.userId);

    if (!toUserId || toUserId === fromUserId) {
      return fail(res, 'invalid_user_id', 400);
    }

    await pool.execute(
      'DELETE FROM connections WHERE from_user_id = ? AND to_user_id = ? LIMIT 1',
      [fromUserId, toUserId]
    );

    return res.json(ok({}));
  } catch (error) {
    console.error('Disconnect error:', error);
    return fail(res, 'internal_error', 500);
  }
});

export default router;
