# IMMEDIATE FIX - Works in 2 minutes

## Option A: Turn OFF Auth enforcement (keeps Firestore/Storage protected)
1. Firebase Console → App Check → APIs tab
2. **Firebase Authentication** → Change to **"Unenforced"**
3. Keep **Cloud Firestore** and **Cloud Storage** as "Enforced"
4. Reload your app - sign in will work immediately!

This allows authentication to work while still protecting your data.

## Option B: Get the Firebase reCAPTCHA key (if available)
1. Firebase Console → App Check → Apps → Click your web app
2. Look for one of these:
   - A "Site key" field showing `6Lc...` 
   - A "Configure reCAPTCHA" button
   - A "Set up attestation provider" link
3. If you see a site key, copy it
4. Add it to `/lib/recaptcha_config.dart`:
   ```dart
   static const String siteKey = 'YOUR_FIREBASE_SITE_KEY_HERE';
   static const bool isConfigured = true;
   ```
5. Run: `flutter run -d chrome`

## Option C: Create a new Firebase reCAPTCHA key
If Firebase isn't showing a reCAPTCHA option:

1. Go to: https://console.firebase.google.com/project/nexum-backend/appcheck/apps
2. Click on your web app
3. If there's no reCAPTCHA option, you may need to:
   - Delete and re-register the web app in App Check
   - OR use the Firebase CLI: `firebase appcheck:recaptcha:create`

## Why this is happening
- Firebase App Check requires a special Firebase-generated reCAPTCHA key
- Google Cloud Console reCAPTCHA keys don't work with App Check
- The key must be embedded in the app for production users
- Debug tokens only work for developers, not end users

## Permanent Production Solution
Once you have the Firebase site key:
1. Add it to `recaptcha_config.dart`
2. Build for production: `flutter build web`
3. Deploy - all users will automatically get App Check tokens
