// backend/src/data/interest-mapping.js
import { FIRST_20_CATEGORY_NAMES, slugify } from './communities.js';

export const CATEGORY_TOPICS = {
  'Arts & Culture': [
    'Art','Painting','Sculpture','Drawing','Photography','Architecture','Graphic Design','Calligraphy','Street Art','Museums','Art History','Theater','Comedy','Opera','Ballet','Contemporary Dance','Musicals','Cultural Heritage','Archaeology','Mythology',
  ],
  'Music': [
    'Pop','Hip-hop','R&B','Afrobeats','Amapiano','Reggae','Dancehall','Jazz','Blues','Rock','Metal','Country','Classical','EDM','House','Techno','Trance','Drum & Bass','K-Pop','J-Pop','Gospel','Songwriting','Music Production','DJing','Piano','Guitar',
  ],
  'Film & TV': [
    'Action Films','Adventure Films','Comedy Films','Drama Films','Thriller','Horror','Sci-Fi','Fantasy','Documentary','Anime','Animation','TV Series','K-Dramas','Nollywood','Bollywood','Screenwriting','Directing','VFX',
  ],
  'Gaming': [
    'Mobile Games','PC Games','Console Games','eSports','MOBA','FPS','Battle Royale','RPG','MMORPG','Strategy','Simulation','Sports Games','Racing Games','Puzzle','Indie Games','Game Design','Game Streaming',
  ],
  'Books & Writing': [
    'Fiction','Nonfiction','Biographies','Self-Help','Fantasy','Science Fiction','Mystery & Thriller','Poetry','Manga','Comics','Creative Writing','Journalism','Blogging','Copywriting','Book Clubs','Literary Criticism',
  ],
  'Science & Tech': [
    'Programming','Mobile Development','Web Front-end','Web Back-end','UI/UX Design','Data Science','Machine Learning','Artificial Intelligence','Computer Vision','NLP','Cybersecurity','Blockchain','Crypto','Cloud Computing','DevOps','Databases','Big Data','AR/VR','Internet of Things','Robotics','Electronics','3D Printing','Mathematics','Astronomy','Physics','Biotechnology','Bioinformatics','Health Tech',
  ],
  'Business & Finance': [
    'Entrepreneurship','Startups','Product Management','Project Management','Marketing','Digital Marketing','Social Media Marketing','SEO','Online Advertising','Sales','Customer Success','E-commerce','Dropshipping','Personal Finance','Stock Investing','Forex Trading','Crypto Investing','Real Estate','Accounting','Economics','Leadership','Management','Human Resources','Negotiation',
  ],
  'Health & Fitness': [
    'Strength Training','Bodybuilding','Cardio','Running','Cycling','Swimming','Yoga','Pilates','CrossFit','HIIT','Boxing','Martial Arts','Stretching & Mobility','Nutrition','Weight Loss','Muscle Gain','Physical Therapy','Sports Science',
  ],
  'Wellness & Lifestyle': [
    'Meditation','Mindfulness','Breathwork','Sleep Optimization','Stress Management','Journaling','Productivity','Time Management','Minimalism','Spiritual Growth','Life Coaching','Work-Life Balance',
  ],
  'Food & Drink': [
    'African Cuisine','Asian Cuisine','European Cuisine','Middle Eastern Cuisine','Street Food','Vegan','Vegetarian','Gluten-Free','Healthy Cooking','Baking','Pastry','BBQ & Grilling','Seafood','Smoothies & Juices','Coffee','Tea','Wine','Craft Beer','Mixology','Quick Recipes','Meal Prep',
  ],
  'Travel & Adventure': [
    'Travel','Road Trips','Backpacking','Luxury Travel','Business Travel','Beaches','Mountains','Safari','National Parks','Camping','Hiking','Trekking','Mountaineering','Snorkeling','Scuba Diving','Skiing','Snowboarding','Urban Exploration','Cultural Tourism','Astro-tourism',
  ],
  'Nature & Environment': [
    'Wildlife','Animal Conservation','Ecology','Recycling','Renewable Energy','Climate Action','Ocean Conservation','Desert Landscapes','Tropical Forests','Sustainable Living','Gardening','Indoor Plants','Birdwatching','Geology','Meteorology',
  ],
  'Sports': [
    'Football (Soccer)','Basketball','Tennis','Volleyball','Handball','Rugby','Boxing','MMA','Judo','Taekwondo','Karate','Wrestling','Fencing','Athletics','Marathon','Trail Running','Road Cycling','Mountain Biking','BMX','Triathlon','Competitive Swimming','Water Polo','Rowing','Canoe & Kayak','Surfing','Kitesurfing','Sailing','Diving','Skiing','Snowboarding','Golf','Cricket','Baseball','Softball','Ice Hockey','Field Hockey','Badminton','Table Tennis','Squash','Darts','Snooker/Billiards','Chess',
  ],
  'Fashion & Beauty': [
    'Fashion','Streetwear','Haute Couture','Personal Styling','Sustainable Fashion','Shoes','Watches','Jewelry','Makeup','Skincare','Haircare','Barbering','Fragrance','Nail Art','Runway Shows',
  ],
  'Home & DIY': [
    'Interior Design','Home Organization','Renovation','DIY Projects','Woodworking','Metalworking','Painting & Wallpaper','Smart Home','Residential Real Estate','Landscaping','Outdoor Gardening','Home Security',
  ],
  'Photo & Video': [
    'Photography','Portrait Photography','Landscape Photography','Street Photography','Macro Photography','Drone Photography','Videography','Video Editing','Vlogging','Live Streaming','Motion Design','Color Grading','Cinematography','Lighting Techniques','Stock Footage',
  ],
  'Auto & Moto': [
    'Cars','Electric Vehicles','Supercars','Car Tuning','Detailing','Safe Driving','Motorcycles','Motocross','Karting','Rally','Formula 1','Off-roading',
  ],
  'Aviation & Space': [
    'Commercial Aviation','Business Aviation','Private Pilots','Airlines','Airports','Plane Spotting','Drones','Flight Simulators','Aviation History','Space Exploration','Rockets','Satellites',
  ],
  'Maritime': [
    'Boats','Yachting','Sailing','Navigation','Fishing','Scuba & Freediving','Ports & Logistics','Maritime History',
  ],
  'Pets & Animals': [
    'Dogs','Dog Training','Cats','Birds','Fish & Aquariums','Reptiles','Small Mammals','Exotic Pets','Pet Adoption','Veterinary Care','Animal Photography','Horse Riding',
  ],
};

export function categorySlug(name) {
  return slugify(name);
}

export function resolveCategoriesForInterests(interests = []) {
  if (!Array.isArray(interests)) return [];
  const interestsLower = new Set(
    interests.filter((s) => typeof s === 'string').map((s) => s.trim().toLowerCase())
  );
  const results = [];
  for (const category of FIRST_20_CATEGORY_NAMES) {
    const topics = CATEGORY_TOPICS[category] || [];
    const catLower = category.toLowerCase();
    let matched = interestsLower.has(catLower);
    if (!matched) {
      for (const t of topics) {
        if (interestsLower.has(t.toLowerCase())) { matched = true; break; }
      }
    }
    if (matched) results.push(category);
  }
  return results;
}