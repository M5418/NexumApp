# NexumApp Deployment Scripts

This directory contains deployment scripts for automating the deployment of NexumApp to Firebase.

## 📁 Available Scripts

### 1. **deploy-all.sh** (Complete Deployment with Cache Busting) ⭐
Deploys both frontend and backend with full checks, optimization, and cache busting.

**What it does:**
- ✓ Checks prerequisites (Flutter, Firebase CLI)
- ✓ Runs Flutter analyzer (lint check)
- ✓ Deep cleans build artifacts (including old web build)
- ✓ Gets latest dependencies
- ✓ Builds Flutter web app
- ✓ Deploys to Firebase Hosting
- ✓ Deploys Firestore rules & indexes
- ✓ Deploys Storage rules
- ✓ Deploys Cloud Functions
- ✓ Shows cache clearing instructions

**Usage:**
```bash
cd /Users/mac/Documents/NexumApp
./scripts/deploy-all.sh
```

**When to use:** 
- Major releases
- After dependency updates
- When you want thorough validation
- Production deployments with UI changes

---

### 2. **deploy-with-cache-clear.sh** (Frontend-Only with Cache Busting)
Deploys only frontend with deep clean and cache busting (no backend services).

**What it does:**
- ✓ Deep cleans all build artifacts
- ✓ Removes old web build completely
- ✓ Builds with cache busting
- ✓ Deploys to Firebase Hosting only
- ✓ Shows cache clearing instructions

**Usage:**
```bash
./scripts/deploy-with-cache-clear.sh
```

**When to use:**
- UI/UX changes only (no backend changes)
- Quick frontend-only deployments
- When deploying critical UI fixes

💡 **Note:** For full deployment with cache busting, use `deploy-all.sh` instead.

---

### 3. **deploy-frontend.sh** (Frontend Only)
Builds and deploys only the Flutter web app to Firebase Hosting.

**What it does:**
- ✓ Runs Flutter analyzer
- ✓ Cleans build
- ✓ Builds Flutter web
- ✓ Deploys to Firebase Hosting

**Usage:**
```bash
./scripts/deploy-frontend.sh
```

**When to use:**
- UI/UX changes
- Frontend bug fixes
- No backend changes needed

---

### 4. **deploy-backend.sh** (Backend Only)
Deploys Firebase backend services without rebuilding the frontend.

**What it does:**
- ✓ Deploys Firestore rules & indexes
- ✓ Deploys Storage rules
- ✓ Deploys Cloud Functions

**Usage:**
```bash
./scripts/deploy-backend.sh
```

**When to use:**
- Database rule changes
- Storage rule updates
- Function modifications
- No frontend changes needed

---

### 5. **deploy-quick.sh** (Quick Deploy)
Fast deployment without cleaning or linting. Use with caution!

**What it does:**
- ⚡ Builds Flutter web (no clean)
- ⚡ Deploys all services

**Usage:**
```bash
./scripts/deploy-quick.sh
```

**When to use:**
- Hot fixes
- Minor changes
- Development deployments
- When you're confident code is ready

⚠️ **Warning:** Skips lint checks and cleaning. Only use when you're sure everything works.

---

## 🚀 Quick Start

### First Time Setup

1. Make scripts executable:
```bash
chmod +x scripts/*.sh
```

2. Ensure you're logged in to Firebase:
```bash
firebase login
```

3. Verify Flutter installation:
```bash
flutter doctor
```

### Deploy Everything
```bash
./scripts/deploy-all.sh
```

---

## 📊 Deployment Checklist

Before deploying, ensure:
- [ ] All changes are committed to git
- [ ] Tests are passing
- [ ] No lint errors
- [ ] Firebase project is correct (`nexum-backend`)
- [ ] Environment variables are set (if any)

---

## 🔧 Troubleshooting

### "Permission denied" error
```bash
chmod +x scripts/*.sh
```

### "Firebase not found"
```bash
brew install firebase-cli
```

### "Flutter not found"
Install Flutter from: https://flutter.dev/docs/get-started/install

### "Not logged in to Firebase"
```bash
firebase login
```

### Build fails with errors
1. Clean the project: `flutter clean`
2. Get dependencies: `flutter pub get`
3. Run analyzer: `flutter analyze`
4. Fix errors before deploying

---

## 🌐 Deployment URLs

- **Web App:** https://nexum-backend.web.app
- **Firebase Console:** https://console.firebase.google.com/project/nexum-backend/overview
- **Functions URL:** https://api-ily4rieqca-uc.a.run.app

---

## 📝 Notes

- Scripts use color-coded output for clarity
- All scripts set `-e` flag (exit on error)
- Frontend build uses `--release` mode for optimization
- Functions deployment may take 2-5 minutes
- Scripts automatically switch to `nexum-backend` project

---

## 🔒 Security

- Never commit Firebase credentials or API keys
- Keep `.env` files in `.gitignore`
- Review Firestore and Storage rules regularly
- Use Firebase App Check for production

---

## 📚 Additional Resources

- [Firebase CLI Reference](https://firebase.google.com/docs/cli)
- [Flutter Build Web](https://docs.flutter.dev/deployment/web)
- [Firebase Hosting](https://firebase.google.com/docs/hosting)
- [Cloud Functions](https://firebase.google.com/docs/functions)

---

**Last Updated:** November 6, 2025  
**Project:** NexumApp  
**Firebase Project:** nexum-backend
