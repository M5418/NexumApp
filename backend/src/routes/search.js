import express from 'express';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';
import { COMMUNITIES } from '../data/communities.js';

const router = express.Router();

// Helpers
function normalizeLimit(v, def = 10, max = 25) {
  const n = Number(v);
  if (!Number.isFinite(n) || n <= 0) return def;
  return Math.min(Math.max(1, Math.floor(n)), max);
}

function computeDisplayName(firstName, lastName, username, email) {
  const first = (firstName || '').trim();
  const last = (lastName || '').trim();
  const user = (username || '').trim();
  const mail = (email || '').trim();
  if (first && last) return `${first} ${last}`;
  if (first) return first;
  if (last) return last;
  if (user) return user;
  if (mail) return mail.split('@')[0];
  return 'User';
}

// GET /api/search?q=term&types=accounts,posts,communities&limit=10
router.get('/', async (req, res) => {
  try {
    const qRaw = (req.query.q ?? '').toString().trim();
    const qLower = qRaw.toLowerCase();
    const limit = normalizeLimit(req.query.limit, 10, 25);

    // types allowed: accounts|users, posts, communities
    const typesParam = (req.query.types ?? 'accounts,posts,communities').toString();
    const types = new Set(
      typesParam
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .filter(Boolean)
    );

    // If empty query, return empty sets (Trending handled in the app)
    if (!qRaw) {
      return res.json(ok({ users: [], posts: [], communities: [], q: qRaw }));
    }

    const like = `%${qRaw}%`;

    // Build tasks (in parallel)
    const tasks = [];

    // 1) Accounts (users)
    let usersPromise = Promise.resolve([]);
    if (types.has('accounts') || types.has('users')) {
      usersPromise = pool
        .query(
          `
          SELECT 
            u.id,
            u.email,
            p.first_name,
            p.last_name,
            p.username,
            p.profile_photo_url
          FROM users u
          LEFT JOIN profiles p ON p.user_id = u.id
          WHERE u.id != ? AND (
                COALESCE(p.username, '') LIKE ?
             OR COALESCE(p.first_name, '') LIKE ?
             OR COALESCE(p.last_name, '') LIKE ?
             OR u.email LIKE ?
          )
          ORDER BY p.first_name, p.last_name, u.email
          LIMIT ?
        `,
          [req.user.id, like, like, like, like, limit]
        )
        .then(([rows]) =>
          rows.map((r) => {
            const name = computeDisplayName(r.first_name, r.last_name, r.username, r.email);
            const displayUsername = r.username
              ? `@${r.username}`
              : r.email
              ? `@${r.email.split('@')[0]}`
              : '@user';
            return {
              id: r.id,
              name,
              username: displayUsername,
              avatarUrl: r.profile_photo_url || null,
            };
          })
        );
    }

    // 2) Posts (content)
    let postsPromise = Promise.resolve([]);
    if (types.has('posts')) {
      postsPromise = pool
        .query(
          `
          SELECT 
            p.*,
            pr.first_name,
            pr.last_name,
            pr.username,
            pr.profile_photo_url
          FROM posts p
          LEFT JOIN profiles pr ON pr.user_id = p.user_id
          WHERE p.content IS NOT NULL
            AND p.content != ''
            AND p.content LIKE ?
          ORDER BY p.created_at DESC
          LIMIT ?
        `,
          [like, limit]
        )
        .then(([rows]) => {
          return rows.map((r) => {
            let imageUrls = null;
            if (r.image_urls) {
              try {
                imageUrls = Array.isArray(r.image_urls) ? r.image_urls : JSON.parse(r.image_urls);
              } catch {
                imageUrls = null;
              }
            }
            const authorName = computeDisplayName(r.first_name, r.last_name, r.username, null);
            return {
              id: r.id,
              user_id: r.user_id,
              post_type: r.post_type,
              content: r.content || '',
              image_url: r.image_url || null,
              image_urls: imageUrls,
              video_url: r.video_url || null,
              created_at: r.created_at,
              updated_at: r.updated_at,
              repost_of: r.repost_of,

              author: {
                name: authorName,
                username: r.username || null,
                avatarUrl: r.profile_photo_url || null,
              },

              counts: {
                likes: Number(r.likes_count || 0),
                comments: Number(r.comments_count || 0),
                shares: Number(r.shares_count || 0),
                reposts: Number(r.reposts_count || 0),
                bookmarks: Number(r.bookmarks_count || 0),
              },

              me: {
                liked: false,
                bookmarked: false,
              },
            };
          });
        });
    }

    // 3) Communities (from dataset)
    let communitiesPromise = Promise.resolve([]);
    if (types.has('communities')) {
      communitiesPromise = Promise.resolve(
        COMMUNITIES.filter((c) => c.name.toLowerCase().includes(qLower)).slice(0, limit)
      );
    }

    const [users, posts, communities] = await Promise.all([
      usersPromise,
      postsPromise,
      communitiesPromise,
    ]);

    return res.json(ok({ users, posts, communities, q: qRaw }));
  } catch (err) {
    console.error('Search error:', err);
    return fail(res, 'internal_error', 500);
  }
});

export default router;