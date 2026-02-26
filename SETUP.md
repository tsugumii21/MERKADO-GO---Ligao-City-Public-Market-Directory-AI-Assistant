# 🚀 MERKADO GO - Quick Setup Guide

This guide will help you set up MERKADO GO in under 15 minutes.

---

## ✅ Pre-Setup Checklist

Before you begin, make sure you have:
- [ ] Flutter SDK installed (3.3.0 or higher)
- [ ] Android Studio or VS Code with Flutter extensions
- [ ] Android device/emulator ready
- [ ] Internet connection

---

## 📋 Step-by-Step Setup

### STEP 1: Install Dependencies (2 minutes)

Open terminal in project root and run:

```bash
flutter pub get
```

Wait for all packages to download.

---

### STEP 2: Firebase Setup (5 minutes)

#### A. Create Firebase Project
1. Go to https://console.firebase.google.com/
2. Click "Add project"
3. Enter project name: **merkado-go**
4. Follow the wizard (Analytics: optional)

#### B. Enable Firebase Services
In your Firebase project:
1. **Authentication**
   - Go to Build → Authentication
   - Click "Get started"
   - Enable "Email/Password" provider
   
2. **Cloud Firestore**
   - Go to Build → Firestore Database
   - Click "Create database"
   - Choose "Start in production mode"
   - Select closest region
   
3. **Cloud Messaging**
   - Go to Build → Cloud Messaging
   - Click "Get started"

#### C. Add Android App
1. Click the Android icon in project overview
2. Package name: `com.merkadogo.app`
3. App nickname: **Merkado Go**
4. Download `google-services.json`
5. Place it in: `android/app/google-services.json` (replace existing)

#### D. Run FlutterFire CLI
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure --project=merkado-go --platforms=android
```

This auto-updates `lib/firebase_options.dart` with correct values.

---

### STEP 3: Cloudinary Setup (3 minutes)

#### A. Create Free Account
1. Go to https://cloudinary.com/users/register_free
2. Sign up (NO credit card required)
3. Verify your email

#### B. Get Credentials
1. From dashboard, copy your **Cloud Name**
2. Go to Settings (gear icon) → Upload
3. Click "Add upload preset"
4. Set:
   - Preset name: **merkado_go_unsigned**
   - Signing Mode: **Unsigned**
   - Click "Save"
5. Copy the preset name

---

### STEP 4: Google Maps API (3 minutes)

#### A. Create/Select Project
1. Go to https://console.cloud.google.com/
2. Select the same project (or create new)

#### B. Enable APIs
1. Go to APIs & Services → Library
2. Search and enable:
   - ✅ Maps SDK for Android
   - ✅ Places API
   - ✅ Geocoding API

#### C. Create API Key
1. Go to APIs & Services → Credentials
2. Click "+ CREATE CREDENTIALS" → API Key
3. Copy the API key
4. Click "Restrict Key" (recommended):
   - Application restrictions: Android apps
   - Add package: `com.merkadogo.app`
   - API restrictions: Select the 3 APIs above
5. Save

---

### STEP 5: Gemini API (2 minutes)

1. Go to https://ai.google.dev/
2. Click "Get API key"
3. Create API key for your project
4. Copy the key

---

### STEP 6: Configure Environment Variables (1 minute)

Open `.env` file in project root and replace ALL placeholders:

```env
CLOUDINARY_CLOUD_NAME=your_actual_cloud_name_from_step_3
CLOUDINARY_UPLOAD_PRESET=merkado_go_unsigned

GEMINI_API_KEY=your_actual_gemini_key_from_step_5

GOOGLE_MAPS_API_KEY=your_actual_maps_key_from_step_4
```

Also update `android/gradle.properties`:
```properties
GOOGLE_MAPS_API_KEY=your_actual_maps_key_from_step_4
```

---

### STEP 7: Run the App! (1 minute)

```bash
# Connect Android device or start emulator

# Check device is connected
flutter devices

# Run the app
flutter run
```

You should see the MERKADO GO splash screen! 🎉

---

## 🐛 Quick Troubleshooting

### Error: "google-services.json not found"
- Make sure you downloaded it from Firebase Console
- Place it exactly in: `android/app/google-services.json`

### Error: "Maps not showing"
- Check API key in both `.env` AND `android/gradle.properties`
- Verify Maps SDK for Android is enabled
- Wait 5-10 minutes for API key activation

### Error: "Cloudinary upload failed"
- Verify cloud name and preset in `.env`
- Make sure preset is set to "Unsigned" in Cloudinary dashboard

### Build errors
```bash
flutter clean
flutter pub get
flutter run
```

---

## ✅ Verification

After running the app, you should see:
- ✅ Green splash screen with "MERKADO GO" text
- ✅ No console errors related to Firebase
- ✅ App doesn't crash

---

## 🎯 Next Steps

**Type YES to proceed to Part 2: Authentication System**

Part 2 will include:
- Login screen
- Signup screen  
- Email verification flow
- Auth state management with Riverpod
- GoRouter setup

---

## 📞 Need Help?

Refer to the main README.md for detailed documentation.

---

**Setup Time: ~15 minutes** ⏱️
