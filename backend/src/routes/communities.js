// backend/src/routes/communities.js
import express from 'express';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';
import { COMMUNITIES, COMMUNITY_BY_ID } from '../data/communities.js';
import { topicsFromInterests } from '../data/interest-mapping.js';

const router = express.Router();

/* Helpers */

function formatName(row) {
  const first = (row.first_name || '').trim();
  const last = (row.last_name || '').trim();
  const username = (row.username || '').trim();
  const email = (row.email || '').trim();
  if (first && last) return `${first} ${last}`;
  if (first) return first;
  if (last) return last;
  if (username) return username;
  if (email) return email.split('@')[0];
  return 'User';
}

function avatarLetterSource(row) {
  const first = (row.first_name || '').trim();
  const username = (row.username || '').trim();
  const email = (row.email || '').trim();
  return (first || username || email || 'U').charAt(0).toUpperCase();
}

async function loadAllUsersWithProfiles() {
  const [rows] = await pool.execute(
    `SELECT u.id, u.email,
            p.first_name, p.last_name, p.username,
            p.profile_photo_url,
            p.interest_domains
       FROM users u
  LEFT JOIN profiles p ON p.user_id = u.id`
  );
  return rows || [];
}

function parseInterests(jsonVal) {
  if (!jsonVal) return [];
  try {
    const data = typeof jsonVal === 'string' ? JSON.parse(jsonVal) : jsonVal;
    return Array.isArray(data) ? data.filter((x) => typeof x === 'string') : [];
  } catch {
    return [];
  }
}

/* Routes */

// GET /api/communities
// Returns ALL per-interest communities (topics)
router.get('/', async (_req, res) => {
  try {
    return res.json(ok(COMMUNITIES));
  } catch (e) {
    console.error('Communities list error:', e);
    return fail(res, 'internal_error', 500);
  }
});

// GET /api/communities/my
// Derived from profile.interest_domains by exact topics and category expansion.
router.get('/my', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT interest_domains FROM profiles WHERE user_id = ? LIMIT 1`,
      [req.user.id]
    );
    if (!rows || rows.length === 0) {
      return res.json(ok([]));
    }

    const myInterests = parseInterests(rows[0].interest_domains);
    const myTopics = topicsFromInterests(myInterests); // canonical topic names
    if (myTopics.length === 0) {
      return res.json(ok([]));
    }

    // Compute member counts for ONLY the user's topics (for pills)
    const allRows = await loadAllUsersWithProfiles();
    const countsByTopic = new Map(myTopics.map((t) => [t, 0]));

    for (const r of allRows) {
      const ints = parseInterests(r.interest_domains);
      const userTopics = topicsFromInterests(ints);
      for (const t of userTopics) {
        if (countsByTopic.has(t)) {
          countsByTopic.set(t, (countsByTopic.get(t) || 0) + 1);
        }
      }
    }

    // Build response from communities dataset
    const data = myTopics
      .map((topicName) => {
        const slug = topicName
          .toLowerCase()
          .replace(/&/g, 'and')
          .replace(/[^a-z0-9]+/g, '-')
          .replace(/^-+|-+$/g, '');
        const base = COMMUNITY_BY_ID[slug];
        if (!base) return null;
        return {
          id: base.id,
          name: base.name,
          bio: base.bio,
          avatarUrl: base.avatarUrl,
          coverUrl: base.coverUrl,
          friendsInCommon: `+${countsByTopic.get(topicName) || 0}`,
          unreadPosts: 0,
        };
      })
      .filter(Boolean);

    return res.json(ok(data));
  } catch (e) {
    console.error('Communities my error:', e);
    return fail(res, 'internal_error', 500);
  }
});

// GET /api/communities/:id
// Details for a specific topic-community
router.get('/:id', async (req, res) => {
  try {
    const id = (req.params.id || '').trim().toLowerCase();
    const community = COMMUNITY_BY_ID[id];
    if (!community) return fail(res, 'community_not_found', 404);

    const rows = await loadAllUsersWithProfiles();
    const targetTopic = community.name;

    let memberCount = 0;
    for (const r of rows) {
      const ints = parseInterests(r.interest_domains);
      const userTopics = topicsFromInterests(ints);
      if (userTopics.includes(targetTopic)) memberCount++;
    }

    return res.json(ok({ ...community, memberCount }));
  } catch (e) {
    console.error('Community get error:', e);
    return fail(res, 'internal_error', 500);
  }
});

// GET /api/communities/:id/members
// Members = users whose interests map to this specific topic.
// (Exact matches on topic + expansion from any selected category containing this topic.)
router.get('/:id/members', async (req, res) => {
  try {
    const id = (req.params.id || '').trim().toLowerCase();
    const community = COMMUNITY_BY_ID[id];
    if (!community) return fail(res, 'community_not_found', 404);

    const targetTopic = community.name;
    const rows = await loadAllUsersWithProfiles();
    const members = [];

    for (const r of rows) {
      const ints = parseInterests(r.interest_domains);
      const userTopics = topicsFromInterests(ints);
      if (userTopics.includes(targetTopic)) {
        members.push({
          id: r.id,
          name: formatName(r),
          username: r.username
            ? `@${r.username}`
            : r.email
              ? `@${r.email.split('@')[0]}`
              : '@user',
          avatarUrl: r.profile_photo_url || null,
          avatarLetter: avatarLetterSource(r),
        });
      }
    }

    return res.json(ok(members));
  } catch (e) {
    console.error('Community members error:', e);
    return fail(res, 'internal_error', 500);
  }
});

export default router;