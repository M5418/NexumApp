#!/usr/bin/env node

/**
 * Create all interest-based communities in Firestore
 * This script creates one community per interest domain
 */

import { initializeApp } from 'firebase/app';
import { getFirestore, collection, doc, setDoc, getDoc, serverTimestamp } from 'firebase/firestore';

// Firebase config (from your firebase_options.dart)
const firebaseConfig = {
  apiKey: "AIzaSyC0yuNXbNGIRYWNI_VWsL-2hnGPmYX6cFYXXvk7-NI6AM35Z4YqM5JIzc",
  authDomain: "nexum-backend.firebaseapp.com",
  projectId: "nexum-backend",
  storageBucket: "nexum-backend.firebasestorage.app",
  messagingSenderId: "1076134014363",
  appId: "1:1076134014363:web:f5f992babfe0f56aa7853e"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

// All interest domains from lib/data/interest_domains.dart (the actual 28 from the file)
const interests = [
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
  'Society & Causes',
  'Religion & Spirituality',
  'Life & Relationships',
  'Education & Languages',
  'Podcasts & Audio',
  'Pop Culture & Collecting',
  'Technology',
  'Business',
  'Finance',
  'Marketing',
  'Entrepreneurship',
  'Science',
  'Health & Wellness',
  'Education',
  'Travel',
  'Food & Cooking',
  'Fashion',
  'Sports',
  'Music',
  'Film & Television',
  'Literature',
  'Art & Design',
  'Photography',
  'Gaming',
  'Environment',
  'Social Issues',
  'Politics',
  'History',
  'Philosophy',
  'Psychology',
  'Parenting',
  'Relationships',
  'Personal Development',
  'Career Development',
  'Real Estate',
  'Automotive',
  'Home Improvement',
  'Gardening',
  'Pets & Animals',
  'Crafts & DIY',
  'Beauty & Skincare',
  'Fitness',
  'Yoga & Meditation',
  'Dance',
  'Theater & Performing Arts',
  'Astronomy',
  'Cryptocurrency',
  'NFTs & Web3',
  'Artificial Intelligence',
  'Robotics',
  'Space Exploration',
  'Climate Change',
  'Renewable Energy',
  'Architecture',
  'Interior Design',
  'Language Learning',
  'Writing',
  'Poetry',
  'Journalism',
  'Podcasting',
  'Video Production',
  'Animation',
  'Comics & Manga',
  'Board Games',
  'Esports',
  'Virtual Reality',
  'Augmented Reality',
  'Spirituality',
  'Religion',
  'Volunteering',
  'Nonprofits',
  'Philanthropy',
  'Human Rights',
  'Mental Health',
  'Nutrition',
  'Alternative Medicine',
  'Running',
  'Cycling',
  'Swimming',
  'Martial Arts',
  'Hiking',
  'Camping',
  'Fishing',
  'Hunting',
  'Surfing',
  'Skiing',
  'Snowboarding',
  'Rock Climbing',
  'Sailing',
  'Scuba Diving',
  'Skydiving',
  'Motorcycles',
  'Aviation',
  'Trains',
  'Collectibles',
  'Antiques',
  'Genealogy',
  'Astrology',
  'Magic & Illusion',
  'Wine & Spirits',
  'Coffee & Tea',
  'Veganism',
  'Vegetarian',
  'Baking',
  'Grilling & BBQ',
  'Cocktails',
  'Beer Brewing',
  'Farming',
  'Sustainability',
  'Minimalism',
  'Tiny Living',
  'Van Life',
  'Digital Nomad',
  'Retirement Planning',
  'Investing',
  'Stock Market',
  'Day Trading',
  'Options Trading',
  'Forex',
  'Commodities',
  'Precious Metals',
  'Insurance',
  'Taxes',
  'Budgeting',
  'Debt Management',
  'Credit',
  'Banking',
  'Loans & Mortgages',
  'Legal',
  'Patents & IP',
  'Startups',
  'Small Business',
  'E-commerce',
  'Dropshipping',
  'Affiliate Marketing',
  'Content Marketing',
  'SEO',
  'Social Media Marketing',
  'Email Marketing',
  'Growth Hacking',
  'Product Management',
  'Project Management',
  'Leadership',
  'Public Speaking',
  'Negotiation',
  'Sales',
  'Customer Service',
  'HR & Recruiting',
  'Remote Work',
  'Freelancing',
  'Side Hustles',
  'Passive Income',
  'Data Science',
  'Machine Learning',
  'Cybersecurity',
  'Cloud Computing',
  'DevOps',
  'Software Development',
  'Web Development',
  'Mobile Development',
  'Game Development',
  'UX/UI Design',
  'Graphic Design',
  '3D Modeling',
  'Sound Design',
  'Music Production',
  'DJ & Mixing',
  'Singing',
  'Guitar',
  'Piano',
  'Drums',
  'Bass',
  'Violin',
  'Saxophone',
  'Electronic Music',
  'Hip Hop',
  'Rock',
  'Jazz',
  'Classical',
  'Country',
  'Blues',
  'Metal',
  'Indie',
  'Pop',
  'K-Pop',
  'Reggae',
  'Folk',
  'World Music',
  'Stand-up Comedy',
  'Improv',
  'Sketch Comedy',
  'Painting',
  'Drawing',
  'Sculpture',
  'Digital Art',
  'Street Art',
  'Calligraphy',
  'Origami',
  'Woodworking',
  'Metalworking',
  'Jewelry Making',
  'Knitting',
  'Sewing',
  'Quilting',
  'Embroidery',
  'Candle Making',
  'Soap Making',
  'Pottery',
  'Glassblowing',
  'Leatherworking',
  'Model Building',
  'Miniatures',
  'Action Figures',
  'Trading Cards',
  'Vintage Toys',
  'Retro Gaming',
  'PC Gaming',
  'Console Gaming',
  'Mobile Gaming',
  'RPGs',
  'Strategy Games',
  'Puzzle Games',
  'Simulation Games',
  'Sports Games',
  'Fighting Games',
  'Racing Games',
  'Adventure Games',
  'Horror Games',
  'Indie Games',
  'Speedrunning',
  'Game Streaming',
  'Chess',
  'Poker',
  'Bridge',
  'Mahjong',
  'Backgammon',
  'Go',
  'Checkers',
  'Scrabble',
  'Sudoku',
  'Crosswords'
];

// Helper to generate community ID from interest name
function getCommunityId(interest) {
  return interest.toLowerCase().replace(/[^a-z0-9]+/g, '-');
}

// Helper to generate bio text
function getBio(interest) {
  return `A community for ${interest} enthusiasts. Connect with like-minded people, share ideas, and discover new content.`;
}

async function createCommunities() {
  console.log(`\n🏘️  Creating ${interests.length} interest-based communities...\n`);
  
  let created = 0;
  let updated = 0;
  
  for (const interest of interests) {
    const communityId = getCommunityId(interest);
    const communityRef = doc(db, 'communities', communityId);
    
    // Check if exists
    const snapshot = await getDoc(communityRef);
    
    const data = {
      name: interest,
      bio: getBio(interest),
      avatarUrl: '',
      coverUrl: '',
      interestDomain: interest,
      memberCount: 0,
      postsCount: 0,
      unreadPosts: 0,
      friendsInCommon: '+0',
      updatedAt: serverTimestamp(),
    };
    
    if (!snapshot.exists()) {
      // Create new
      await setDoc(communityRef, {
        ...data,
        createdAt: serverTimestamp(),
      });
      created++;
      console.log(`✅ Creating: ${interest}`);
    } else {
      // Update existing (fix empty names)
      await setDoc(communityRef, data, { merge: true });
      updated++;
      console.log(`🔄 Updating: ${interest}`);
    }
  }
  
  console.log(`\n✅ Done!`);
  console.log(`   📝 Created: ${created} communities`);
  console.log(`   🔄 Updated: ${updated} communities`);
  console.log(`   📊 Total: ${interests.length} communities\n`);
}

// Run the script
createCommunities()
  .then(() => {
    console.log('✨ All communities created successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Error creating communities:', error);
    process.exit(1);
  });
