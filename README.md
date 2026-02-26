# 🛒 MERKADO GO

**Ligao City Public Market Directory & AI Assistant**

A Flutter mobile app (Android only) that helps shoppers navigate the Ligao City Public Market using interactive maps, AI-powered assistance, and comprehensive stall directory features.

---

## 📱 Features

### User Features
- 🗺️ **Interactive Google Maps** - Navigate the market with real-time stall locations
- 🔍 **Smart Search** - Find stalls by name OR search by ingredient/product
- 🤖 **AI Chatbot "Kado"** - Powered by Gemini 1.5 Pro for market assistance
- ⭐ **Favorites** - Save frequently visited stalls
- 📊 **Stall Directory** - Browse by category (Pork, Poultry, Beef, Vegetables, etc.)
- 📍 **Stall Details** - Photos, hours, location, and more
- 🚨 **Report System** - Report issues with stalls
- 🔐 **Email Authentication** - Secure login with email verification

### Admin Features
- 🛠️ **Stall Management** - Add, edit, and delete stall information
- 📋 **Reports Dashboard** - Review and resolve user reports
- 👥 **Separate Admin Portal** - Role-based access control

---

## 🛠️ Tech Stack

| Category | Technology |
|----------|-----------|
| **Framework** | Flutter (Dart) |
| **Platform** | Android ONLY |
| **Backend** | Firebase (Auth, Firestore, FCM) |
| **Image Storage** | Cloudinary (free tier, no credit card) |
| **Maps** | Google Maps Flutter + Google Places API |
| **AI** | Gemini 1.5 Pro |
| **State Management** | Riverpod 2.x |
| **Navigation** | GoRouter |
| **Auth** | Email + Password (Email Verification) |

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** (>=3.3.0)
- **Android Studio** or **VS Code** with Flutter extensions
- **Android device/emulator** (API level 21+)
- **Firebase account**
- **Cloudinary account** (free)
- **Google Cloud Console** account (for Maps API)
- **Gemini API key**

---

### 📦 Installation

#### 1️⃣ Clone & Install Dependencies

```bash
# Navigate to project directory
cd r:\Code\MerkadoGo

# Install Flutter dependencies
flutter pub get
```

#### 2️⃣ Firebase Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project named **merkado-go**
3. Enable the following services:
   - ✅ **Authentication** (Email/Password provider)
   - ✅ **Cloud Firestore** (production mode)
   - ✅ **Cloud Messaging** (FCM)
   - ✅ **Analytics** (optional)
   - ❌ **DO NOT enable Firebase Storage** (we use Cloudinary)

4. Add Android app:
   - Package name: `com.merkadogo.app`
   - Download `google-services.json`
   - Place it in: `android/app/google-services.json`

5. Generate Firebase configuration:
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase (Android only)
flutterfire configure --project=merkado-go --platforms=android
```

This will automatically update `lib/firebase_options.dart`

#### 3️⃣ Cloudinary Setup

1. Go to [Cloudinary](https://cloudinary.com/) and sign up (FREE, no credit card)
2. From the dashboard, note:
   - **Cloud Name**
   - Create an **Upload Preset**:
     - Go to Settings → Upload → Add Upload Preset
     - Set to **Unsigned**
     - Note the preset name

#### 4️⃣ Google Maps API Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable these APIs:
   - **Maps SDK for Android**
   - **Places API**
   - **Geocoding API**
4. Create API Key:
   - Navigate to **APIs & Services → Credentials**
   - Click **Create Credentials → API Key**
   - Restrict the key (recommended):
     - Application restrictions: Android apps
     - Add package name: `com.merkadogo.app`
     - API restrictions: Select the 3 APIs above

#### 5️⃣ Gemini API Setup

1. Go to [Google AI Studio](https://ai.google.dev/)
2. Click **Get API Key**
3. Create a new API key for your project

#### 6️⃣ Configure Environment Variables

1. Open the `.env` file in the project root
2. Replace placeholder values with your actual credentials:

```env
# Cloudinary Configuration
CLOUDINARY_CLOUD_NAME=your_actual_cloud_name
CLOUDINARY_UPLOAD_PRESET=your_actual_upload_preset

# Gemini AI Configuration
GEMINI_API_KEY=your_actual_gemini_api_key

# Google Maps Configuration
GOOGLE_MAPS_API_KEY=your_actual_google_maps_api_key
```

3. **IMPORTANT**: Also update `android/gradle.properties`:
```properties
GOOGLE_MAPS_API_KEY=your_actual_google_maps_api_key
```

⚠️ **NEVER commit `.env` to version control** (already in `.gitignore`)

---

### ▶️ Run the App

```bash
# Check connected devices
flutter devices

# Run on connected Android device/emulator
flutter run

# Or run in release mode
flutter run --release
```

---

## 📂 Project Structure

```
lib/
├── main.dart                          # App entry point
├── firebase_options.dart              # Firebase configuration
├── core/
│   ├── constants/
│   │   ├── app_strings.dart          # UI strings
│   │   ├── app_colors.dart           # Color palette
│   │   ├── app_secrets.dart          # Environment variables
│   │   └── market_categories.dart    # Stall categories
│   ├── services/
│   │   ├── cloudinary_service.dart   # Image upload service
│   │   ├── gemini_service.dart       # AI chatbot service
│   │   └── notification_service.dart # FCM service
│   ├── router/
│   │   └── app_router.dart           # GoRouter configuration
│   ├── theme/
│   │   └── app_theme.dart            # Material theme
│   └── widgets/
│       └── custom_bottom_nav.dart    # Reusable widgets
├── features/
│   ├── auth/                         # Authentication
│   ├── map/                          # Interactive map
│   ├── stalls/                       # Stall directory
│   ├── chat/                         # AI chatbot
│   ├── profile/                      # User profile
│   └── admin/                        # Admin panel
├── models/                           # Data models
└── providers/                        # Riverpod providers
```

---

## 🗄️ Firestore Schema

### `users/{uid}`
```json
{
  "uid": "string",
  "username": "string",        // Unique, used for login
  "email": "string",
  "profilePhotoUrl": "string", // Cloudinary URL
  "role": "user | admin",
  "favoriteStalls": ["stallId1", "stallId2"],
  "fcmToken": "string",
  "createdAt": "timestamp"
}
```

### `stalls/{stallId}`
```json
{
  "stallId": "string",
  "name": "string",
  "category": "string",
  "products": ["product1", "product2"],
  "address": "string",
  "photoUrls": ["url1", "url2"], // Cloudinary URLs
  "openTime": "08:00",
  "closeTime": "18:00",
  "daysOpen": ["Mon", "Tue", "Wed"],
  "latitude": 13.5391,
  "longitude": 123.5197,
  "isActive": true,
  "updatedAt": "timestamp"
}
```

### `reports/{reportId}`
```json
{
  "reportId": "string",
  "userId": "string",
  "stallId": "string",
  "stallName": "string",
  "description": "string",
  "status": "pending | reviewed | resolved",
  "createdAt": "timestamp"
}
```

### `usernames/{username}`
```json
{
  "uid": "string"  // For username uniqueness validation
}
```

---

## 🔑 Key Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `firebase_core` | ^3.6.0 | Firebase initialization |
| `firebase_auth` | ^5.3.1 | Email authentication |
| `cloud_firestore` | ^5.4.4 | Database |
| `firebase_messaging` | ^15.1.3 | Push notifications |
| `flutter_riverpod` | ^2.6.1 | State management |
| `go_router` | ^14.6.2 | Navigation |
| `google_generative_ai` | ^0.4.6 | Gemini AI |
| `google_maps_flutter` | ^2.9.0 | Interactive maps |
| `http` | ^1.2.2 | Cloudinary uploads |
| `image_picker` | ^1.1.2 | Image selection |
| `flutter_image_compress` | ^2.3.0 | Image compression |
| `cached_network_image` | ^3.4.1 | Image caching |
| `flutter_dotenv` | ^5.2.1 | Environment variables |

---

## ⚠️ Important Notes

### ❌ What This App Does NOT Use
- **iOS** - Android only
- **Firebase Storage** - We use Cloudinary instead (no credit card required)
- **Phone/SMS OTP** - Email verification only
- **Mobile number fields** - None in the entire app

### ✅ What This App DOES Use
- **Email + Password authentication** with email verification
- **Username OR Email** for login
- **Cloudinary** for all image uploads (stall photos, profile pictures)
- **Gemini 1.5 Pro** for AI chatbot
- **Google Maps** for interactive market navigation

---

## 🐛 Troubleshooting

### Issue: Firebase not connecting
```bash
# Re-run FlutterFire configuration
flutterfire configure --project=merkado-go --platforms=android
```

### Issue: Google Maps not showing
1. Check `GOOGLE_MAPS_API_KEY` in both `.env` and `android/gradle.properties`
2. Verify Maps SDK for Android is enabled in Google Cloud Console
3. Ensure API key is not restricted or properly configured for your app

### Issue: Image upload failing
1. Verify Cloudinary credentials in `.env`
2. Check that upload preset is set to "Unsigned" in Cloudinary dashboard
3. Ensure `INTERNET` permission is in `AndroidManifest.xml`

### Issue: Build errors
```bash
# Clean build
flutter clean
flutter pub get
cd android && ./gradlew clean && cd ..
flutter run
```

---

## 📝 Development Checklist

### Part 1: ✅ Project Setup & Configuration
- [x] Flutter project created (Android only)
- [x] All dependencies installed
- [x] Firebase configured
- [x] Cloudinary service created
- [x] Environment variables set up
- [x] Android permissions configured
- [x] App compiles and runs

### Part 2: 🔜 Authentication System
- [ ] Login screen
- [ ] Signup screen
- [ ] Email verification screen
- [ ] Auth repository
- [ ] Auth provider (Riverpod)
- [ ] GoRouter setup with auth state

### Part 3: 🔜 Interactive Map & Stalls
- [ ] Google Maps integration
- [ ] Stall markers
- [ ] Search functionality
- [ ] Stall detail bottom sheet
- [ ] Stall repository

### Part 4: 🔜 Stall Directory & Favorites
- [ ] Stall list screen
- [ ] Category filtering
- [ ] Favorites feature
- [ ] Search by product

### Part 5: 🔜 AI Chatbot (Kado)
- [ ] Gemini service
- [ ] Chat UI
- [ ] Message history
- [ ] Context-aware responses

### Part 6: 🔜 User Profile & Reports
- [ ] Profile screen
- [ ] Edit profile (with Cloudinary upload)
- [ ] Report stall feature
- [ ] Reports list

### Part 7: 🔜 Admin Panel
- [ ] Admin login
- [ ] Admin dashboard
- [ ] Manage stalls (CRUD)
- [ ] View/resolve reports

### Part 8: 🔜 Notifications & Polish
- [ ] FCM setup
- [ ] Push notifications
- [ ] App theme refinement
- [ ] Loading states
- [ ] Error handling
- [ ] Final testing

---

## 👨‍💻 Developer

Built with ❤️ for the Ligao City Public Market community

---

## 📄 License

This project is proprietary software for Ligao City Public Market.

---

## 🙏 Acknowledgments

- Firebase for backend services
- Cloudinary for free image hosting
- Google for Maps and Gemini AI
- Flutter team for the amazing framework

---

**Ready to build MERKADO GO!** 🚀

For questions or issues, please refer to the documentation or contact the development team.
