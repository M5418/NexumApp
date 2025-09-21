import express from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';
import { generateUserId } from '../utils/id-generator.js';
import authMiddleware from '../middleware/auth.js';

const router = express.Router();

// Validation schemas
const signupSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8)
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1)
});

// POST /api/auth/signup
router.post('/signup', async (req, res) => {
  try {
    const { email, password } = signupSchema.parse(req.body);
    
    // Check if user already exists
    const [existing] = await pool.execute(
      'SELECT id FROM users WHERE email = ?',
      [email]
    );
    
    if (existing.length > 0) {
      return fail(res, 'email_already_exists', 409);
    }
    
    // Generate custom 12-character ID
    const userId = generateUserId();
    
    // Hash password
    const passwordHash = await bcrypt.hash(password, 12);
    
    // Insert user with custom ID
    await pool.execute(
      'INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)',
      [userId, email, passwordHash]
    );
    
    // Generate JWT
    const token = jwt.sign(
      { sub: userId, email },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );
    
    res.json(ok({
      token,
      user: { id: userId, email }
    }));
    
  } catch (error) {
    if (error instanceof z.ZodError) {
      return fail(res, 'validation_error', 400);
    }
    console.error('Signup error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// POST /api/auth/login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = loginSchema.parse(req.body);
    
    // Find user
    const [users] = await pool.execute(
      'SELECT id, email, password_hash FROM users WHERE email = ?',
      [email]
    );
    
    if (users.length === 0) {
      return fail(res, 'invalid_credentials', 401);
    }
    
    const user = users[0];
    
    // Verify password
    const isValid = await bcrypt.compare(password, user.password_hash);
    
    if (!isValid) {
      return fail(res, 'invalid_credentials', 401);
    }
    
    // Generate JWT
    const token = jwt.sign(
      { sub: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );
    
    res.json(ok({
      token,
      user: { id: user.id, email: user.email }
    }));
    
  } catch (error) {
    if (error instanceof z.ZodError) {
      return fail(res, 'validation_error', 400);
    }
    console.error('Login error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// GET /api/auth/me
router.get('/me', authMiddleware, async (req, res) => {
  try {
    res.json(ok({
      id: req.user.id,
      email: req.user.email
    }));
  } catch (error) {
    console.error('Me error:', error);
    return fail(res, 'internal_error', 500);
  }
});

// POST /api/auth/logout
router.post('/logout', (req, res) => {
  res.json(ok({}));
});

export default router;
