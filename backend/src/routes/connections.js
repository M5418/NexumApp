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

    const outbound = outRows.map(r => r.to_user_id);
    const inbound = inRows.map(r => r.from_user_id);

    return res.json(ok({ inbound, outbound }));
  } catch (error) {
    console.error('Connections list error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Get connections for a specific user (by ID) summarized into inbound/outbound
router.get('/user/:userId', async (req, res) => {
  try {
    const userId = req.params.userId;

    if (!userId || typeof userId !== 'string') {
      return fail(res, 'invalid_user_id', 400);
    }

    const [rows] = await pool.execute(
      'SELECT other_user_id, direction FROM v_user_connections WHERE user_id = ? ORDER BY created_at DESC',
      [userId]
    );

    const inbound = rows.filter(r => r.direction === 'inbound').map(r => r.other_user_id);
    const outbound = rows.filter(r => r.direction === 'outbound').map(r => r.other_user_id);

    return res.json(ok({ inbound, outbound }));
  } catch (error) {
    console.error('User connections summary error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Get detailed connections for a specific user (includes other user's basic profile fields)
router.get('/user/:userId/detailed', async (req, res) => {
  try {
    const userId = req.params.userId;

    if (!userId || typeof userId !== 'string') {
      return fail(res, 'invalid_user_id', 400);
    }

    const [rows] = await pool.execute(
      `SELECT user_id, other_user_id, direction, created_at,
              other_username, other_first_name, other_last_name
         FROM v_user_connections_detailed
        WHERE user_id = ?
        ORDER BY created_at DESC`,
      [userId]
    );

    return res.json(ok({ connections: rows }));
  } catch (error) {
    console.error('User connections detailed error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// Create a connection from the authenticated user to :userId
router.post('/:userId', async (req, res) => {
  try {
    const fromUserId = req.user.id;
    const toUserId = req.params.userId;

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
    const toUserId = req.params.userId;

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
