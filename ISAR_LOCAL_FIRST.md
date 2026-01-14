# Isar Local-First Architecture

Ultra-fluid CRUD with Isar as primary READ layer and Firestore as source of truth.

## Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                             │
│  (Binds to Isar streams for instant rendering)              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Local Repositories                          │
│  LocalPostRepository, LocalProfileRepository, etc.          │
│  - watchLocal(): Stream<List<T>> from Isar                  │
│  - syncRemote(): Delta sync from Firestore                  │
│  - CRUD with optimistic writes                              │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│      Isar Database      │     │       Firestore         │
│  (Primary READ layer)   │     │  (Source of truth)      │
│  - Instant local reads  │     │  - Background sync      │
│  - Optimistic writes    │     │  - Delta updates        │
└─────────────────────────┘     └─────────────────────────┘
```

## Key Features

### 1. Instant Local Reads
- UI binds to `watchLocal()` streams from Isar
- Data displays immediately from local cache
- No network wait for initial render

### 2. Background Sync
- `syncRemote()` fetches only changed documents (delta sync)
- Uses `updatedAt` cursor for efficient queries
- Backward compatible with docs missing `updatedAt` (falls back to `createdAt`)

### 3. Optimistic Writes
- CRUD operations write to Isar immediately
- UI updates instantly with `syncStatus: 'pending'`
- Firestore write queued via WriteQueue
- Status updates to `'synced'` or `'failed'` after server response

### 4. Web Fallback
- Isar only works on mobile (iOS/Android)
- Web falls back to Firestore cache-first behavior
- `isIsarSupported` check gates all Isar operations

## Files Structure

```
lib/local/
├── local_store.dart          # LocalStore interface + isIsarSupported
├── isar_db.dart              # Isar database singleton
├── local.dart                # Barrel export
├── utils/
│   └── hash_utils.dart       # fastHash for Isar IDs
├── models/
│   ├── post_lite.dart        # Lightweight post model
│   ├── profile_lite.dart     # Lightweight profile model
│   ├── conversation_lite.dart # Lightweight conversation model
│   ├── message_lite.dart     # Lightweight message model
│   ├── podcast_lite.dart     # Lightweight podcast model
│   ├── book_lite.dart        # Lightweight book model
│   └── community_post_lite.dart # Community post model
├── sync/
│   ├── sync_cursor_store.dart # Per-module sync cursors
│   ├── sync_scheduler.dart   # Background sync scheduler
│   └── initial_seeder.dart   # First-run Firestore→Isar seeding
└── repositories/
    ├── local_post_repository.dart
    ├── local_profile_repository.dart
    ├── local_conversation_repository.dart
    ├── local_message_repository.dart
    ├── local_podcast_repository.dart
    ├── local_book_repository.dart
    └── local_community_post_repository.dart
```

## Pages Wired to Local-First

| Page | File | Mobile (Isar) | Web (Hive) |
|------|------|---------------|------------|
| Home Feed | `lib/home_feed_page.dart` | ✅ | ✅ |
| Video Scroll | `lib/video_scroll_page.dart` | ✅ | ✅ |
| Conversations | `lib/conversations_page.dart` | ✅ | ✅ |
| Community | `lib/community_page.dart` | ✅ | ✅ |
| Podcasts | `lib/podcasts/podcasts_home_page.dart` | ✅ | ✅ |
| Books | `lib/books/books_home_page.dart` | ✅ | ✅ |

## Web Local Store (Hive)

On web, we use Hive instead of Isar for local storage:

```
lib/local/web/
├── web_local_store.dart    # Hive boxes + in-memory cache
└── web_cache_warmer.dart   # Prefetch data from Firestore at startup
```

### How Web Local Store Works

1. **In-Memory Cache**: All data is loaded into memory maps for sync reads
2. **Hive Persistence**: Data persists in IndexedDB via Hive boxes
3. **Warm Cache**: At app start, `WebCacheWarmer` fetches latest data from Firestore

### Verification Logs (Web)

Look for these logs in browser console:
```
✅ Hive (web) database initialized
🔥 Starting cache warm...
📝 Warmed 100 posts
💬 Warmed 50 conversations
🎙️ Warmed 50 podcasts
📚 Warmed 50 books
✅ Cache warm complete in XXXms
🌐 [Web] Loaded 20 posts from Hive
🌐 [Web] Loaded 30 conversations from Hive
```

### Performance Comparison

| Platform | Local DB | Initial Load | Subsequent Loads |
|----------|----------|--------------|------------------|
| Mobile | Isar | < 100ms | < 50ms |
| Web | Hive | < 200ms | < 100ms |
| Web (old) | Firestore cache | 300-500ms | 200-300ms |

## How to Verify

### 1. Isar is Primary Read Path

```dart
// In any page, check if data comes from Isar:
final posts = LocalPostRepository().getLocalSync(limit: 20);
debugPrint('Loaded ${posts.length} posts from Isar');

// Or watch the stream:
LocalPostRepository().watchLocal(limit: 20).listen((posts) {
  debugPrint('Isar stream: ${posts.length} posts');
});
```

### 2. Initial Seeding Works

Check debug logs on first app launch after update:
```
[InitialSeeder] 🌱 Starting initial seed check...
[InitialSeeder] 🌱 Seeding posts from Firestore...
[InitialSeeder] ✅ Seeded 200 posts
[InitialSeeder] ✅ Initial seeding complete
```

### 3. Sync Cursors are Stored

```dart
// Check stored cursors:
final cursors = SyncCursorStore().getAllCursors();
debugPrint('Sync cursors: $cursors');
// Output: {posts: 2024-01-15 10:30:00, conversations: 2024-01-15 10:25:00}
```

### 4. Delta Sync is Working

Check debug logs during background sync:
```
[LocalPostRepo] 🔄 Syncing posts since: 2024-01-15 10:30:00
[LocalPostRepo] ✅ Synced 5 posts
```

### 5. Database Statistics

```dart
final stats = IsarDB().getStats();
debugPrint('Isar stats: $stats');
// Output: {posts: 200, profiles: 50, conversations: 30, messages: 500, ...}
```

## Sync Triggers

The `SyncScheduler` triggers sync:
- **On app start**: After first frame renders
- **On app resume**: When app comes to foreground
- **Periodic**: Every 3 minutes when idle
- **On module open**: When user navigates to a screen

## Backward Compatibility

### Existing Firestore Data
- No schema changes required
- Models handle missing `updatedAt` gracefully
- Falls back to `createdAt` for ordering
- Gradually backfill `updatedAt` via server-side jobs (optional)

### Web Platform
- Isar operations are gated by `isIsarSupported`
- Web continues using Firestore cache-first pattern
- No breaking changes for web users

## Lite Models

Each model contains only what UI needs:

| Model | Key Fields |
|-------|------------|
| `PostLite` | id, authorId, authorName, caption, mediaThumbUrls, counts, createdAt |
| `ProfileLite` | uid, displayName, photoUrl, bio, followerCount |
| `ConversationLite` | id, memberIds, lastMessageText, lastMessageAt, unreadCount |
| `MessageLite` | id, conversationId, senderId, type, text, mediaUrl, createdAt |
| `PodcastLite` | id, title, coverUrl, durationSeconds |
| `BookLite` | id, title, coverUrl, epubUrl, pdfUrl |

## Optimistic Write Flow

```
1. User creates post
   ↓
2. LocalPostRepository.createPostOptimistic()
   - Generate client-side ID
   - Write to Isar with syncStatus='pending'
   - Return immediately (UI shows post)
   ↓
3. WriteQueue.enqueue(...)
   - Queue Firestore write
   - Retry with exponential backoff on failure
   ↓
4. On success: updateSyncStatus(postId, 'synced')
   On failure: updateSyncStatus(postId, 'failed')
```

## Performance Traces

Firebase Performance Monitoring traces are added for:
- `feed_initial_load`: Time to display first posts
- `feed_pagination`: Time to load next page
- `video_scroll_load`: Time to load video feed
- `conversations_load`: Time to load conversation list
- `chat_load`: Time to load chat messages

## TikTok-like Video Constraints

The video scroll page enforces:
- **1 active player**: Only current video plays
- **Preload 0-2**: Based on `PerformanceCoordinator().videoPreloadCount`
- **Autoplay toggle**: Based on `PerformanceCoordinator().videoAutoplayEnabled`
- **Aggressive disposal**: `_cleanupDistantVideos()` removes players outside range
- **Thumbnail-first**: Show image until video is focused

## Troubleshooting

### Isar not initializing
Check debug logs for:
```
[IsarDB] ✅ Isar database initialized at /path/to/documents
```

If missing, check:
- Platform is iOS/Android (not web)
- `path_provider` can access documents directory
- No conflicting Isar instances

### Sync not running
Check:
```
[SyncScheduler] ✅ SyncScheduler initialized
[SyncScheduler] 📝 Registered sync for: posts
```

If missing, ensure `IsarDB().init()` completed successfully.

### Data not appearing
1. Check if seeding completed: `SyncCursorStore().isSeeded('posts')`
2. Check local count: `LocalPostRepository().getLocalCount()`
3. Force re-seed: `InitialSeeder().forceReseedAll()`

## Code Generation

After modifying Isar models, regenerate:
```bash
dart run build_runner build --delete-conflicting-outputs
```
