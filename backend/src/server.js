// File: backend/src/server.js
// Lines: 1-103
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
import communitiesRoutes from './routes/communities.js';
import communityPostsRoutes from './routes/community-posts.js';
import communityRepostsRoutes from './routes/community-posts-reposts.js';
import repostsRoutes from './routes/posts-reposts.js';
import booksRoutes from './routes/books.js';
import podcastsRoutes from './routes/podcasts.js';
import mentorshipRoutes from './routes/mentorship.js';
import searchRoutes from './routes/search.js';
import notificationsRoutes from './routes/notifications.js';
import kycRoutes from './routes/kyc.js';
import reportsRoutes from './routes/reports.js'; // <— NEW

const app = express();
const PORT = process.env.PORT || 8080;

const corsOptions = {
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);
    const allowedStatic = [
      'http://localhost:3000',
      'http://10.0.2.2:3000',
      'http://ec2-35-183-183-199.ca-central-1.compute.amazonaws.com',
    ];
    const isLocalDev = /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin);
    if (allowedStatic.includes(origin) || isLocalDev) return callback(null, true);
    return callback(new Error(`CORS blocked for origin: ${origin}`));
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
};

app.use(cors(corsOptions));
app.options('*', cors(corsOptions));
app.use(express.json({ limit: '10mb' }));

app.get('/health', (req, res) => res.json({ ok: true }));
app.get('/healthz', (req, res) => res.json({ ok: true }));

// Auth and user resources
app.use('/api/auth', authRoutes);
app.use('/api/files', authMiddleware, filesRoutes);
app.use('/api/profile', authMiddleware, profileRoutes);
app.use('/api/users', authMiddleware, usersRoutes);
app.use('/api/connections', authMiddleware, connectionsRoutes);

// Global posts
app.use('/api/posts', authMiddleware, postsRoutes);
app.use('/api/posts', authMiddleware, repostsRoutes);

// Other APIs
app.use('/api/invitations', authMiddleware, invitationsRoutes);
app.use('/api/conversations', authMiddleware, conversationsRoutes);
app.use('/api/messages', authMiddleware, messagesRoutes);
app.use('/api/stories', authMiddleware, storiesRoutes);

// Communities + community posts
app.use('/api/communities', authMiddleware, communitiesRoutes);
app.use('/api/communities', authMiddleware, communityPostsRoutes);
app.use('/api/communities', authMiddleware, communityRepostsRoutes);

// Content libraries
app.use('/api/books', authMiddleware, booksRoutes);
app.use('/api/podcasts', authMiddleware, podcastsRoutes);

// Mentorship
app.use('/api/mentorship', authMiddleware, mentorshipRoutes);

// Notifications
app.use('/api/notifications', authMiddleware, notificationsRoutes);

// Reports (NEW)
app.use('/api/reports', authMiddleware, reportsRoutes);

// Search
app.use('/api/search', authMiddleware, searchRoutes);

// KYC
app.use('/api/kyc', authMiddleware, kycRoutes);

// Errors
app.use((err, req, res, next) => {
  console.error('Global error:', err);
  res.status(500).json({ ok: false, error: 'internal_server_error' });
});
app.use('*', (req, res) => res.status(404).json({ ok: false, error: 'not_found' }));

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
});