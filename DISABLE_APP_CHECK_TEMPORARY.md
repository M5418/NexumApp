# Emergency: Disable App Check Temporarily

If nothing else works, disable App Check completely while we fix it properly:

## Option 1: Remove App Check from code
In `lib/main.dart`, comment out ALL App Check activation:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // TEMPORARILY DISABLED - App Check causing 401 errors
  /*
  if (kIsWeb) {
    // App Check code here...
  } else {
    // App Check code here...
  }
  */
  
  runApp(const MyApp());
}
```

## Option 2: Delete the web app from App Check
1. Firebase Console → App Check → Apps
2. Find "nexumbackendfirebase"
3. Click 3 dots → Remove/Delete
4. This removes App Check for web but keeps it for iOS/Android

## Option 3: Create a new Firebase project
If App Check is stuck in a bad state:
1. Create a new Firebase project
2. Don't enable App Check initially
3. Migrate your app to the new project
4. Enable App Check properly later

## Why this is happening
Firebase App Check has a bug where:
- It forces "monitoring" mode for Authentication
- Monitoring mode still blocks requests (not truly "monitoring only")
- The reCAPTCHA configuration UI is sometimes hidden
- Google Cloud reCAPTCHA keys don't work with Firebase App Check

## Long-term fix
Contact Firebase support with:
- Your project ID: nexum-backend
- Issue: Can't unenforce Authentication, stuck in monitoring mode
- Request: Either allow full unenforcement OR show reCAPTCHA v3 configuration
