// backend/src/routes/communities.js
import express from 'express';
import pool from '../db/db.js';
import { ok, fail } from '../utils/response.js';
import { COMMUNITIES, COMMUNITY_BY_ID } from '../data/communities.js';
import { resolveCategoriesForInterests, categorySlug } from '../data/interest-mapping.js';

const router = express.Router();

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
  } catch { return []; }
}

// List all predefined communities
router.get('/', async (_req, res) => {
  try { return res.json(ok(COMMUNITIES)); }
  catch (e) { console.error(e); return fail(res, 'internal_error', 500); }
});

// List current user's communities (derived from interests)
router.get('/my', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT interest_domains FROM profiles WHERE user_id = ? LIMIT 1`,
      [req.user.id]
    );
    if (!rows || rows.length === 0) return res.json(ok([]));
    const myInterests = parseInterests(rows[0].interest_domains);
    const myCategories = resolveCategoriesForInterests(myInterests);
    if (myCategories.length === 0) return res.json(ok([]));

    const allRows = await loadAllUsersWithProfiles();
    const countsBySlug = new Map(myCategories.map((c) => [categorySlug(c), 0]));

    for (const r of allRows) {
      const cats = resolveCategoriesForInterests(parseInterests(r.interest_domains));
      for (const c of cats) {
        const s = categorySlug(c);
        if (countsBySlug.has(s)) countsBySlug.set(s, (countsBySlug.get(s) || 0) + 1);
      }
    }

    const data = myCategories.map((cat) => {
      const s = categorySlug(cat);
      const base = COMMUNITY_BY_ID[s];
      if (!base) return null;
      return {
        id: base.id,
        name: base.name,
        bio: base.bio,
        avatarUrl: base.avatarUrl,
        coverUrl: base.coverUrl,
        friendsInCommon: `+${countsBySlug.get(s) || 0}`,
        unreadPosts: 0,
      };
    }).filter(Boolean);

    return res.json(ok(data));
  } catch (e) {
    console.error(e);
    return fail(res, 'internal_error', 500);
  }
});

// Community details
router.get('/:id', async (req, res) => {
  try {
    const id = (req.params.id || '').trim().toLowerCase();
    const community = COMMUNITY_BY_ID[id];
    if (!community) return fail(res, 'community_not_found', 404);

    const rows = await loadAllUsersWithProfiles();
    const target = community.name;
    let memberCount = 0;
    for (const r of rows) {
      const cats = resolveCategoriesForInterests(parseInterests(r.interest_domains));
      if (cats.includes(target)) memberCount++;
    }
    return res.json(ok({ ...community, memberCount }));
  } catch (e) {
    console.error(e);
    return fail(res, 'internal_error', 500);
  }
});

// Community members (derived)
router.get('/:id/members', async (req, res) => {
  try {
    const id = (req.params.id || '').trim().toLowerCase();
    const community = COMMUNITY_BY_ID[id];
    if (!community) return fail(res, 'community_not_found', 404);

    const target = community.name;
    const rows = await loadAllUsersWithProfiles();
    const members = [];
    for (const r of rows) {
      const cats = resolveCategoriesForInterests(parseInterests(r.interest_domains));
      if (cats.includes(target)) {
        members.push({
          id: r.id,
          name: formatName(r),
          username: r.username ? `@${r.username}` : (r.email ? `@${r.email.split('@')[0]}` : '@user'),
          avatarUrl: r.profile_photo_url || null,
          avatarLetter: avatarLetterSource(r),
        });
      }
    }
    return res.json(ok(members));
  } catch (e) {
    console.error(e);
    return fail(res, 'internal_error', 500);
  }
});

export default router;