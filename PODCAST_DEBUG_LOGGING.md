# 🔍 Podcast Pages - Comprehensive Debug Logging

## 🎯 What Was Added

Added detailed logging throughout all podcast pages to diagnose why data isn't displaying.

---

## 📝 Logging Added to Each Page

### 1. **My Episodes Page** (`lib/podcasts/my_episodes_page.dart`)

```dart
🎙️ [My Episodes] Fetching podcasts for user: {uid}
🎙️ [My Episodes] Fetched {count} podcasts
⚠️ [My Episodes] No podcasts found for user
❌ [My Episodes] Error loading podcasts: {error}
```

**What to Look For:**
- Does it show the correct user UID?
- Does it fetch any podcasts?
- Are there any Firebase errors?

---

### 2. **My Library Page** (`lib/podcasts/my_library_page.dart`)

```dart
📚 [My Library] Starting to load playlists...
⚠️ [My Library] No current user
📚 [My Library] Fetching playlists for user: {uid}
📚 [My Library] Query returned {count} playlists
📚 [My Library] Loaded {count} playlists
⚠️ [My Library] No playlists found for user
❌ [My Library] Error loading playlists: {error}
```

**What to Look For:**
- Is user authenticated?
- Does Firestore return any documents?
- Are there query permission errors?

---

### 3. **Podcast Categories Page** (`lib/podcasts/podcast_categories_page.dart`)

```dart
📚 [Categories] Starting to load categories...
📚 [Categories] Fetched {count} podcasts
📚 [Categories] Grouped into {count} categories
⚠️ [Categories] No categories found
❌ [Categories] Error loading categories: {error}
```

**What to Look For:**
- Does it fetch any published podcasts?
- Can it group them by category?
- Are there any errors?

---

### 4. **Podcast Repository** (`lib/repositories/firebase/firebase_podcast_repository.dart`)

```dart
🔍 [PodcastRepo] listPodcasts called with: authorId={...}, isPublished={...}
🔍 [PodcastRepo] Added filter: authorId={uid}
🔍 [PodcastRepo] Added filter: isPublished={bool}
🔍 [PodcastRepo] Added filter: category={name}
🔍 [PodcastRepo] Added orderBy: createdAt descending
🔍 [PodcastRepo] Executing Firestore query...
✅ [PodcastRepo] Query returned {count} documents
✅ [PodcastRepo] Mapped {count} podcasts
❌ [PodcastRepo] FirebaseException: {code} - {message}
🔄 [PodcastRepo] Falling back to simple query
✅ [PodcastRepo] Fallback returned {count} documents
```

**What to Look For:**
- Are filters being applied correctly?
- Does Firestore return documents?
- Are there permission or index errors?
- Does fallback query work if main query fails?

---

## 🔍 How to Debug

### Step 1: Run the App
```bash
flutter run -d chrome
```

### Step 2: Open Browser Console
- Chrome DevTools → Console tab
- Watch for emoji prefixed logs: 🎙️ 📚 🔍 ✅ ❌ ⚠️

### Step 3: Navigate to Podcast Pages
1. **My Library** - Check for playlist logs
2. **My Episodes** - Check for user podcast logs
3. **Categories** - Check for category grouping logs

### Step 4: Look for Patterns

**If you see:**
```
🔍 [PodcastRepo] Query returned 0 documents
```
→ **Problem:** No podcasts in Firestore matching the criteria

**If you see:**
```
❌ [PodcastRepo] FirebaseException: permission-denied
```
→ **Problem:** Firestore security rules blocking access

**If you see:**
```
❌ [PodcastRepo] FirebaseException: failed-precondition
```
→ **Problem:** Missing Firestore index

**If you see:**
```
⚠️ [My Episodes] No podcasts found for user
```
→ **Problem:** User hasn't created any podcasts OR authorId field mismatch

**If you see:**
```
⚠️ [My Library] No current user
```
→ **Problem:** User not authenticated

---

## 🐛 Common Issues & Solutions

### Issue 1: "No podcasts found"
**Possible Causes:**
1. Firestore `podcasts` collection is empty
2. No podcasts match the filters (e.g., `isPublished: true`)
3. User's UID doesn't match any `authorId` fields

**Check:**
```
Go to Firebase Console → Firestore Database → podcasts collection
- Are there any documents?
- Do they have isPublished: true?
- Do they have authorId fields?
```

---

### Issue 2: "Permission denied"
**Possible Causes:**
1. Firestore security rules blocking read access
2. User not authenticated

**Check:**
```
Firebase Console → Firestore Database → Rules
Look for:
match /podcasts/{podcastId} {
  allow read: if true;  // Or appropriate rule
}
```

**Temporary Fix (DEV ONLY):**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /podcasts/{document=**} {
      allow read: if true;  // Allow all reads
      allow write: if request.auth != null;
    }
    match /playlists/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

### Issue 3: "Failed precondition" or "Index required"
**Possible Causes:**
1. Query uses multiple filters without index
2. Combination of `where()` + `orderBy()` requires composite index

**Solution:**
The code already has fallback logic:
```dart
try {
  // Try main query
} on FirebaseException catch (e) {
  // Fall back to simple query
}
```

If fallback also fails, create the index:
1. Firebase Console → Error message will have index creation link
2. Click link → Create index
3. Wait 2-5 minutes for index to build

---

### Issue 4: "No current user"
**Possible Causes:**
1. User not signed in
2. Firebase Auth not initialized
3. Session expired

**Check:**
```
Look for these logs at app startup:
✅ Auth token refreshed: true
🔍 Attempting to fetch profile for uid: {uid}
```

---

## 📊 Expected Log Flow

### Successful My Episodes Load:
```
🎙️ [My Episodes] Fetching podcasts for user: V3WC78cb1tNbpX5nYAF8RVDbxG13
🔍 [PodcastRepo] listPodcasts called with: authorId=V3WC78cb1tNbpX5nYAF8RVDbxG13, isPublished=true
🔍 [PodcastRepo] Added filter: authorId=V3WC78cb1tNbpX5nYAF8RVDbxG13
🔍 [PodcastRepo] Added filter: isPublished=true
🔍 [PodcastRepo] Executing Firestore query...
✅ [PodcastRepo] Query returned 5 documents
✅ [PodcastRepo] Mapped 5 podcasts
🎙️ [My Episodes] Fetched 5 podcasts
```

### Successful Categories Load:
```
📚 [Categories] Starting to load categories...
🔍 [PodcastRepo] listPodcasts called with: authorId=null, isPublished=true
🔍 [PodcastRepo] Added filter: isPublished=true
🔍 [PodcastRepo] Executing Firestore query...
✅ [PodcastRepo] Query returned 15 documents
✅ [PodcastRepo] Mapped 15 podcasts
📚 [Categories] Fetched 15 podcasts
📚 [Categories] Grouped into 4 categories
```

### Successful My Library Load:
```
📚 [My Library] Starting to load playlists...
📚 [My Library] Fetching playlists for user: V3WC78cb1tNbpX5nYAF8RVDbxG13
📚 [My Library] Query returned 3 playlists
📚 [My Library] Loaded 3 playlists
```

---

## 🔧 Firestore Data Structure Requirements

### Podcasts Collection:
```javascript
podcasts/{podcastId}
{
  "title": "Episode 1",
  "author": "John Doe",
  "authorId": "V3WC78cb1tNbpX5nYAF8RVDbxG13",  // REQUIRED
  "description": "...",
  "coverUrl": "https://...",
  "audioUrl": "https://...",
  "category": "Technology",  // For categories page
  "isPublished": true,  // REQUIRED for display
  "playCount": 100,
  "likes": ["uid1", "uid2"],
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

### Playlists Collection:
```javascript
playlists/{playlistId}
{
  "name": "My Favorites",
  "userId": "V3WC78cb1tNbpX5nYAF8RVDbxG13",  // REQUIRED
  "podcastIds": ["podcast1", "podcast2"],
  "isPrivate": false,
  "createdAt": Timestamp
}
```

---

## ✅ Next Steps

1. **Run the app with logging:**
   ```bash
   flutter run -d chrome
   ```

2. **Navigate to each podcast page:**
   - My Library
   - My Episodes  
   - Categories

3. **Copy console output** and check for:
   - Red ❌ errors
   - Orange ⚠️ warnings
   - How many documents returned

4. **Check Firestore Console:**
   - Do podcasts exist?
   - Do they have `authorId` and `isPublished` fields?
   - Do playlists exist with `userId` field?

5. **Check Security Rules:**
   - Can users read podcasts?
   - Can authenticated users read their own playlists?

---

## 📋 Checklist

- [ ] Run app and open browser console
- [ ] Navigate to My Library page
- [ ] Check logs for playlist count
- [ ] Navigate to My Episodes page
- [ ] Check logs for podcast count
- [ ] Navigate to Categories page
- [ ] Check logs for category grouping
- [ ] Look for any ❌ errors
- [ ] Check Firestore has data
- [ ] Check security rules allow read access

---

**Status:** 🔍 **Debug logging ready - please run app and share console output**

All logging is in place. The logs will tell us exactly where the issue is:
- Authentication?
- Empty Firestore?
- Permission denied?
- Missing data fields?
- Query errors?
