# Interest-Based Communities System

## ✅ Implementation Complete

The app now automatically creates and manages communities based on user interests. Each of the 28 interest domains has its own community.

---

## 🎯 How It Works

### 1. Auto-Created Communities (28 Total)

On app startup, the system creates communities for each interest domain:

```
Arts & Culture → arts-culture
Music → music  
Film & TV → film-tv
Gaming → gaming
Books & Writing → books-writing
Science & Tech → science-tech
Business & Finance → business-finance
Health & Fitness → health-fitness
Wellness & Lifestyle → wellness-lifestyle
Food & Drink → food-drink
Travel & Adventure → travel-adventure
Nature & Environment → nature-environment
Sports → sports
Fashion & Beauty → fashion-beauty
Home & DIY → home-diy
Photo & Video → photo-video
Auto & Moto → auto-moto
Aviation & Space → aviation-space
Maritime → maritime
Pets & Animals → pets-animals
Society & Causes → society-causes
Religion & Spirituality → religion-spirituality
Life & Relationships → life-relationships
Education & Languages → education-languages
Podcasts & Audio → podcasts-audio
Pop Culture & Collecting → pop-culture-collecting
```

**Firestore Structure:**
```
communities/
  ├─ arts-culture/
  │   ├─ name: "Arts & Culture"
  │   ├─ bio: "A community for Arts & Culture enthusiasts"
  │   ├─ interestDomain: "Arts & Culture"
  │   ├─ memberCount: X
  │   └─ members/
  │       └─ userId123: { userId, displayName, joinedAt, ... }
  └─ music/
      ├─ name: "Music"
      └─ members/
          └─ userId456: { ... }
```

---

### 2. Auto-Sync on Interest Selection

**When a user selects interests:**
1. User chooses interests (e.g., "Music", "Gaming", "Travel & Adventure")
2. System saves to `users/{uid}/interest_domains`
3. **Automatically creates membership documents** in corresponding communities
4. Updates `memberCount` in each community

**Example:**
```
User selects: ["Music", "Gaming"]
↓
Creates:
- communities/music/members/{userId}
- communities/gaming/members/{userId}
↓
Increments:
- communities/music/memberCount +1
- communities/gaming/memberCount +1
```

---

### 3. Auto-Sync on Interest Changes

**When a user updates interests (adds/removes):**

**Adding an interest:**
- Creates membership in that community
- Increments `memberCount`

**Removing an interest:**
- Deletes membership from that community
- Decrements `memberCount`

**Example:**
```
User changes from ["Music", "Gaming"] to ["Music", "Sports"]
↓
Removes:
- communities/gaming/members/{userId}
- communities/gaming/memberCount -1
↓
Adds:
- communities/sports/members/{userId}
- communities/sports/memberCount +1
```

---

## 📱 User Experience

### Communities List (Conversations Page)

**Shows only user's communities** based on their interests:

```dart
// Uses: FirebaseCommunityRepository.listMine()
// Queries: collectionGroup('members').where('userId', '==', currentUserId)
// Returns: Only communities the user is a member of
```

**Console Output:**
```
🔄 Syncing interests to communities for user abc123
   New interests: 3 items
   Current interests: 2 items
   To add: 1
   To remove: 0
   ➕ Adding to: Sports
✅ Community memberships synced successfully
✅ Communities.listMine fetched: 3 communities
```

---

### Create Post Page

**Community selector** shows only user's communities:

```dart
// Uses: context.read<CommunityRepository>().listMine()
// Returns: Only communities the user is part of (based on interests)
// User can select which community to post in
```

---

## 🔧 Technical Implementation

### Files Created/Modified

**New Files:**
- `lib/services/community_interest_sync_service.dart` - Core sync logic

**Modified Files:**
- `lib/interest_selection_page.dart` - Sync on first-time interest selection
- `lib/profile_page.dart` - Sync when editing interests in profile  
- `lib/main.dart` - Initialize communities on app startup
- `lib/repositories/firebase/firebase_community_repository.dart` - Diagnostic logging

**Firestore Rules:**
```javascript
// Communities (public read)
match /communities/{communityId} {
  allow read: if true;
  allow create, update: if signedIn();
  
  match /members/{memberId} {
    allow read: if true;
    allow create, update, delete: if signedIn();
  }
}

// CollectionGroup support
match /{path=**}/members/{memberId} {
  allow read: if true;
}
```

**Firestore Indexes:**
- Single-field indexes auto-created by Firebase for `members.userId` and `members.uid`
- Composite indexes for invitations and podcasts (in firestore.indexes.json)

---

## 🚀 Deployment & Testing

### Step 1: Run the App

The communities will auto-create on first run:

```bash
flutter run -d chrome --dart-define=RECAPTCHA_ENTERPRISE_SITE_KEY=YOUR_KEY
```

**Console Output:**
```
🏘️  Initializing interest-based communities...
✅ Created 28 new communities
✅ Interest communities initialized: 28 created, 0 existing
```

### Step 2: Select Interests

1. User goes to interest selection page (onboarding or profile edit)
2. Selects interests (e.g., "Music", "Gaming", "Sports")
3. Saves

**Console Output:**
```
🔄 Syncing interests to communities for user V3WC78cb...
   New interests: 3 items
   ➕ Adding to: Music
   ➕ Adding to: Gaming
   ➕ Adding to: Sports
✅ Community memberships synced successfully
```

### Step 3: View Communities

Navigate to Conversations page → Communities tab

**Expected Result:**
```
✅ Communities.listMine fetched: 3 communities
```

Shows: Music, Gaming, Sports communities

### Step 4: Create Post

Go to Create Post page → Select community dropdown

**Expected Result:**
Shows only the 3 communities the user is part of

---

## 🔍 Verification Steps

### Check Firestore Database

1. **Go to Firebase Console → Firestore**
2. **Verify `communities` collection** has 28 documents
3. **Check a community** (e.g., `music`)
   - Should have `memberCount > 0` if anyone selected Music
4. **Check `communities/music/members`** subcollection
   - Should contain documents for each user who selected Music
   - Each document has `userId`, `displayName`, `joinedAt`

### Test Interest Changes

1. **Edit profile** → Edit interests
2. **Remove "Gaming"**, add "Travel & Adventure"
3. **Save**

**Expected in Firestore:**
- `communities/gaming/members/{userId}` - DELETED
- `communities/gaming/memberCount` - DECREMENTED
- `communities/travel-adventure/members/{userId}` - CREATED
- `communities/travel-adventure/memberCount` - INCREMENTED

**Expected in App:**
- Communities list shows: Music, Sports, Travel & Adventure (no Gaming)

---

## 📊 Data Flow Diagram

```
User selects interests
        ↓
ProfileApi.update({'interest_domains': [...]})
        ↓
CommunityInterestSyncService.syncUserInterests([...])
        ↓
    Compare old vs new interests
        ↓
    ┌──────────────┬──────────────┐
    ↓              ↓              ↓
Add new       Remove old    No change
memberships   memberships   (skip)
    ↓              ↓
Firestore      Firestore
batch          batch
create         delete
    ↓              ↓
Update         Update
memberCount    memberCount
    ↓              ↓
    └──────────────┴──────────────┘
                ↓
        Communities.listMine()
                ↓
    Shows only user's communities
```

---

## ✅ Benefits

1. **Automatic** - No manual community joining required
2. **Consistent** - 1:1 mapping between interests and communities
3. **Organized** - All users with same interest are in same community
4. **Scalable** - New interests = new communities automatically
5. **Real-time** - Changes sync immediately

---

## 🎨 Future Enhancements

### Optional (Not Implemented Yet):

1. **Community Avatars/Covers**
   - Add default images for each interest domain
   - Update `communities/{id}/avatarUrl` and `coverUrl`

2. **Community Analytics**
   - Track posts per community
   - Most active communities
   - Community growth metrics

3. **Community Moderators**
   - Assign moderators based on activity
   - Moderation tools for community content

4. **Nested Interests**
   - Sub-communities for specific interests
   - E.g., Music → Jazz, Hip-hop, Classical

5. **Private Communities**
   - Allow users to create private interest groups
   - Separate from main interest communities

---

## 🐛 Troubleshooting

### Communities Not Appearing

**Symptom:** `listMine()` returns empty

**Checks:**
1. User has selected interests? Check `users/{uid}/interest_domains`
2. Membership documents exist? Check `communities/{id}/members/{uid}`
3. CollectionGroup rule exists? Check Firestore rules
4. Single-field index built? Check Firebase Console → Indexes

**Fix:**
```dart
// Re-sync interests
await CommunityInterestSyncService().syncUserInterests(currentInterests);
```

### Duplicate Communities

**Symptom:** Multiple communities with same name

**Cause:** `initializeInterestCommunities()` called multiple times with different IDs

**Fix:**
- Delete duplicates manually in Firestore
- The system checks `snapshot.exists` to prevent duplicates

### MemberCount Incorrect

**Symptom:** `memberCount` doesn't match actual members

**Fix:**
```javascript
// Run in Firebase Console
const admin = require('firebase-admin');
const db = admin.firestore();

// Recount members for all communities
const communities = await db.collection('communities').get();
for (const doc of communities.docs) {
  const members = await doc.ref.collection('members').get();
  await doc.ref.update({ memberCount: members.size });
}
```

---

**System is now live! Users automatically join communities based on their interests. 🎉**
