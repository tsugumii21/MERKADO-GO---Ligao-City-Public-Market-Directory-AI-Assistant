# 🎯 MERKADO GO - Developer Quick Reference

---

## 🚀 Daily Development Commands

```bash
# Run app
flutter run

# Run with hot reload
flutter run --hot

# Clean build
flutter clean && flutter pub get

# Run tests
flutter test

# Check for issues
flutter doctor

# Update dependencies
flutter pub get
flutter pub upgrade

# Generate code (later when using build_runner)
dart run build_runner build --delete-conflicting-outputs
```

---

## 📁 Key File Locations

| Purpose | Path |
|---------|------|
| **Main entry** | `lib/main.dart` |
| **Environment vars** | `.env` |
| **Firebase config** | `lib/firebase_options.dart` |
| **Android manifest** | `android/app/src/main/AndroidManifest.xml` |
| **Build config** | `android/app/build.gradle` |
| **Cloudinary service** | `lib/core/services/cloudinary_service.dart` |
| **App colors** | `lib/core/constants/app_colors.dart` |
| **App strings** | `lib/core/constants/app_strings.dart` |

---

## 🔑 API Keys Checklist

Make sure these are configured:

- [ ] `.env` → `CLOUDINARY_CLOUD_NAME`
- [ ] `.env` → `CLOUDINARY_UPLOAD_PRESET`
- [ ] `.env` → `GEMINI_API_KEY`
- [ ] `.env` → `GOOGLE_MAPS_API_KEY`
- [ ] `android/gradle.properties` → `GOOGLE_MAPS_API_KEY`
- [ ] `android/app/google-services.json` (downloaded from Firebase)

---

## 🗂️ Firestore Collections

| Collection | Purpose |
|------------|---------|
| `users/{uid}` | User profiles (username, email, role, favorites) |
| `stalls/{stallId}` | Stall information (name, category, location, photos) |
| `reports/{reportId}` | User-submitted reports about stalls |
| `usernames/{username}` | Username uniqueness validation |

---

## 🎨 Color Palette

```dart
AppColors.primary          // #2E7D32 (Market Green)
AppColors.secondary        // #FF6F00 (Market Orange)
AppColors.background       // #F5F5F5
AppColors.surface          // #FFFFFF
AppColors.textPrimary      // #212121
AppColors.textSecondary    // #757575
AppColors.success          // #4CAF50
AppColors.error            // #F44336
AppColors.warning          // #FFC107
AppColors.info             // #2196F3
```

---

## 📦 Key Packages

| Package | Purpose |
|---------|---------|
| `firebase_core` | Firebase initialization |
| `firebase_auth` | Email + password authentication |
| `cloud_firestore` | Database |
| `firebase_messaging` | Push notifications |
| `flutter_riverpod` | State management |
| `go_router` | Navigation |
| `google_generative_ai` | Gemini AI chatbot |
| `google_maps_flutter` | Interactive maps |
| `http` | Cloudinary uploads |
| `image_picker` | Select images |
| `flutter_image_compress` | Compress images |
| `cached_network_image` | Display images from URLs |
| `flutter_dotenv` | Load .env variables |

---

## 🛠️ Common Tasks

### Add a New Package
```bash
flutter pub add package_name
flutter pub get
```

### Upload Image to Cloudinary
```dart
final cloudinary = CloudinaryService();
final imageUrl = await cloudinary.uploadImage(
  imageFile,
  folder: 'stalls', // or 'profiles'
);
```

### Access Environment Variables
```dart
import 'package:merkado_go/core/constants/app_secrets.dart';

final cloudName = AppSecrets.cloudinaryCloudName;
final mapsKey = AppSecrets.googleMapsApiKey;
```

### Access Firebase
```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final auth = FirebaseAuth.instance;
final firestore = FirebaseFirestore.instance;
```

---

## 🐛 Troubleshooting

### Issue: Build fails
```bash
flutter clean
flutter pub get
cd android && ./gradlew clean && cd ..
flutter run
```

### Issue: Maps not showing
- Check API key in `.env` AND `android/gradle.properties`
- Verify Maps SDK for Android is enabled
- Restart app

### Issue: Firebase connection fails
```bash
flutterfire configure --project=merkado-go --platforms=android
```

### Issue: Image upload fails
- Verify Cloudinary credentials in `.env`
- Check internet permission in AndroidManifest.xml
- Ensure upload preset is "Unsigned"

---

## 📱 Testing on Device

### Enable USB Debugging (Android)
1. Go to Settings → About Phone
2. Tap "Build Number" 7 times
3. Go back → Developer Options
4. Enable "USB Debugging"
5. Connect device via USB

### Run on Device
```bash
flutter devices
flutter run
```

---

## 🎯 Feature Checklist

### Part 1: ✅ COMPLETE
- [x] Project setup
- [x] Dependencies
- [x] Firebase config
- [x] Cloudinary service
- [x] Environment variables
- [x] Android configuration

### Part 2: 🔜 Authentication
- [ ] Login screen
- [ ] Signup screen
- [ ] Email verification
- [ ] Auth providers
- [ ] GoRouter

### Part 3: 🔜 Map & Stalls
- [ ] Google Maps
- [ ] Stall markers
- [ ] Search
- [ ] Stall details

### Part 4: 🔜 Directory & Favorites
- [ ] Stall list
- [ ] Categories
- [ ] Favorites

### Part 5: 🔜 AI Chatbot
- [ ] Gemini integration
- [ ] Chat UI

### Part 6: 🔜 Profile & Reports
- [ ] Profile screen
- [ ] Edit profile
- [ ] Report stalls

### Part 7: 🔜 Admin Panel
- [ ] Admin login
- [ ] Manage stalls
- [ ] View reports

### Part 8: 🔜 Polish
- [ ] FCM notifications
- [ ] Theme refinement
- [ ] Testing

---

## 🔗 Useful Links

- **Firebase Console**: https://console.firebase.google.com/
- **Cloudinary Dashboard**: https://cloudinary.com/console
- **Google Cloud Console**: https://console.cloud.google.com/
- **Gemini API**: https://ai.google.dev/
- **Flutter Docs**: https://docs.flutter.dev/
- **Riverpod Docs**: https://riverpod.dev/

---

## 📞 Support

For issues or questions:
1. Check README.md
2. Check SETUP.md
3. Review this quick reference
4. Check Flutter/Firebase documentation

---

**Last Updated:** Part 1 Complete  
**Current Version:** 1.0.0+1  
**Platform:** Android Only
