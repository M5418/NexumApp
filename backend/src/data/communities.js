// backend/src/data/communities.js
// Build per-interest communities from CATEGORY_TOPICS.
// Each interest (topic) becomes one community.

import { ALL_TOPICS } from './interest-mapping.js';

export function slugify(name) {
  return name
    .toLowerCase()
    .replace(/&/g, 'and')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

// Each topic is its own community
export const COMMUNITIES = ALL_TOPICS.map((topic) => {
  const id = slugify(topic);
  return {
    id,
    name: topic,
    bio: `A community for ${topic} — learn, share and grow with people who love ${topic}.`,
    avatarUrl: `https://picsum.photos/seed/${id}-avatar/200/200`,
    coverUrl: `https://picsum.photos/seed/${id}-cover/1200/400`,
  };
});

export const COMMUNITY_BY_ID = Object.fromEntries(
  COMMUNITIES.map((c) => [c.id, c])
);