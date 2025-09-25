import 'dotenv/config';
import express from 'express';
import cors from 'cors';

import authRoutes from './routes/auth.js';
import filesRoutes from './routes/files.js';
import profileRoutes from './routes/profile.js';
import usersRoutes from './routes/users.js';
import connectionsRoutes from './routes/connections.js';
import invitationsRoutes from './routes/invitations.js';
import authMiddleware from './middleware/auth.js';
import postsRoutes from './routes/posts-simplified.js';
import conversationsRoutes from './routes/conversations.js';
import messagesRoutes from './routes/messages.js';
import storiesRoutes from './routes/stories.js';

const app = express();
const PORT = process.env.PORT || 8080;

// CORS configuration (place BEFORE routes)
const corsOptions = {
  // Allow your static origins plus any localhost/127.0.0.1 on any port (Flutter Web dev server)
  origin: (origin, callback) => {
    // Allow requests with no origin, like curl/Postman or health checks
    if (!origin) return callback(null, true);

    const allowedStatic = [
      'http://localhost:3000',
      'http://10.0.2.2:3000',
      'http://ec2-35-183-183-199.ca-central-1.compute.amazonaws.com',
    ];
    const isLocalDev = /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin);

    if (allowedStatic.includes(origin) || isLocalDev) {
      return callback(null, true);
    }
    return callback(new Error(`CORS blocked for origin: ${origin}`));
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
};

app.use(cors(corsOptions));
// Handle preflight for all routes
app.options('*', cors(corsOptions));

app.use(express.json({ limit: '10mb' }));

// Health endpoints
app.get('/health', (req, res) => {
  res.json({ ok: true });
});

app.get('/healthz', (req, res) => {
  res.json({ ok: true });
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/files', authMiddleware, filesRoutes);
app.use('/api/profile', authMiddleware, profileRoutes);
app.use('/api/users', authMiddleware, usersRoutes);
app.use('/api/connections', authMiddleware, connectionsRoutes);
app.use('/api/posts', authMiddleware, postsRoutes);
app.use('/api/invitations', authMiddleware, invitationsRoutes);
app.use('/api/conversations', authMiddleware, conversationsRoutes);
app.use('/api/messages', authMiddleware, messagesRoutes);
app.use('/api/stories', authMiddleware, storiesRoutes);

// Global error handler
app.use((err, req, res, next) => {
  console.error('Global error:', err);
  res.status(500).json({
    ok: false,
    error: 'internal_server_error',
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    ok: false,
    error: 'not_found',
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
});