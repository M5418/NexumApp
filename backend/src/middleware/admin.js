// File: backend/src/middleware/admin.js
import pool from '../db/db.js';

export default async function adminOnly(req, res, next) {
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ ok: false, error: 'unauthorized' });

    const [rows] = await pool.execute('SELECT is_admin FROM users WHERE id = ?', [userId]);
    if (rows.length === 0 || !rows[0].is_admin) {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }

    return next();
  } catch (e) {
    console.error('adminOnly error:', e);
    return res.status(500).json({ ok: false, error: 'internal_error' });
  }
}