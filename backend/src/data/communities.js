// backend/src/data/communities.js
function slugify(name) {
    return name
      .toLowerCase()
      .replace(/&/g, 'and')
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');
  }
  
  export const FIRST_20_CATEGORY_NAMES = [
    'Arts & Culture',
    'Music',
    'Film & TV',
    'Gaming',
    'Books & Writing',
    'Science & Tech',
    'Business & Finance',
    'Health & Fitness',
    'Wellness & Lifestyle',
    'Food & Drink',
    'Travel & Adventure',
    'Nature & Environment',
    'Sports',
    'Fashion & Beauty',
    'Home & DIY',
    'Photo & Video',
    'Auto & Moto',
    'Aviation & Space',
    'Maritime',
    'Pets & Animals',
  ];
  
  export const COMMUNITIES = FIRST_20_CATEGORY_NAMES.map((name) => {
    const id = slugify(name);
    return {
      id,
      name,
      bio: `A community for ${name} — learn, share and grow with people who love ${name}.`,
      avatarUrl: `https://picsum.photos/seed/${id}-avatar/200/200`,
      coverUrl: `https://picsum.photos/seed/${id}-cover/1200/400`,
    };
  });
  
  export const COMMUNITY_BY_ID = Object.fromEntries(
    COMMUNITIES.map((c) => [c.id, c])
  );
  
  export { slugify };