# Part 9 — Services & AI Integration

## Service Files

All services are in `lib/core/services/`:

| File | Service | Status |
|------|---------|--------|
| `gemini_service.dart` | Google Gemini AI chatbot | ✅ Active |
| `cloudinary_service.dart` | Image upload to Cloudinary | ✅ Active |
| `notification_service.dart` | Push notifications (FCM) | ⚠️ Stub only |

---

## 1. Gemini AI Service ("Aling Suki" / "Kado")

**File**: `lib/core/services/gemini_service.dart`

### What It Does
- Powers the in-app AI chatbot that helps users find market stalls and products
- Uses **Google Gemini 2.5 Flash** model (`gemini-2.5-flash`)
- Supports both **English** and **Tagalog** conversation
- Has full knowledge of every stall in the market (loaded into system prompt)

### How It Works

```
User types: "Saan may nagbebenta ng baboy?"
    ↓
GeminiService receives the message
    ↓
System prompt includes:
  - Role instructions ("You are Kado, a market assistant...")
  - Current date/time in Philippine Standard Time (UTC+8)
  - Full dump of ALL stalls with names, products, categories, hours, location
    ↓
Gemini API processes and returns response
    ↓
Response displayed as markdown in chat bubble
    ↓
Conversation history maintained for follow-up questions
```

### System Prompt Structure

The system prompt tells Gemini:
1. **Who it is**: "You are Kado (also called Aling Suki), a friendly and helpful AI assistant for Ligao City Public Market"
2. **What it knows**: Complete stall data is injected into the prompt — name, categories, products, operating hours, days, location, status
3. **Language**: Respond in the same language the user uses (English or Tagalog)
4. **Context**: Current Philippine date and time, so it can answer "which stalls are open now?"
5. **Formatting**: Use markdown for responses (bold, lists, etc.)

### API Key
- Loaded from `.env` as `GEMINI_API_KEY`
- Accessed via `AppSecrets.geminiApiKey` from `lib/core/constants/app_secrets.dart`

### Chat State
- Managed by `ChatController` (`lib/features/chat/presentation/chat_controller.dart`)
- Messages stored as `ChatMessage` objects (role: "user" or "model")
- `isStreaming` flag on messages indicates when AI is still generating
- History is maintained per session (resets on sign out or app restart)

### Where It Appears in the UI
- **Map Screen** (`/home`) — expandable chat panel docked at bottom-right
- Not available on other tabs or in admin portal

---

## 2. Cloudinary Image Service

**File**: `lib/core/services/cloudinary_service.dart`

### What It Does
- Uploads images (stall photos, profile photos) to Cloudinary cloud storage
- Returns a public URL that is stored in Firestore
- Uses **unsigned upload preset** (no server-side signing needed)

### Upload Flow

```
1. User picks image (camera or gallery)
       ↓
2. Image read as Uint8List bytes (web-compatible — no dart:io File)
       ↓
3. Bytes compressed via flutter_image_compress
       ↓
4. Base64-encode the bytes
       ↓
5. POST to Cloudinary REST API:
   https://api.cloudinary.com/v1_1/{cloud_name}/image/upload
   Body: { file: "data:image/jpeg;base64,{base64data}", upload_preset: "merkadogo" }
       ↓
6. Response contains secure_url → saved to Firestore
```

### Configuration
All values from `.env`:

| Key | Purpose |
|-----|---------|
| `CLOUDINARY_CLOUD_NAME` | Your Cloudinary account cloud name |
| `CLOUDINARY_API_KEY` | API key (used in REST calls) |
| `CLOUDINARY_API_SECRET` | API secret |
| `CLOUDINARY_UPLOAD_PRESET` | Unsigned upload preset name (default: `"merkadogo"`) |
| `CLOUDINARY_URL` | Full API base URL |

### Where It's Used
- **Edit Profile Screen** → upload profile photo
- **Add/Edit Stall Screen** → upload stall photo(s)

### Web Compatibility
The service was specifically refactored to accept `Uint8List` bytes instead of `dart:io` `File` objects, so it works on both **Android** and **Web** platforms.

---

## 3. Notification Service (Stub)

**File**: `lib/core/services/notification_service.dart`

### Current Status: ⚠️ NOT IMPLEMENTED

This service exists as a **skeleton** for future Firebase Cloud Messaging (FCM) integration:

- `initialize()` → placeholder, throws `UnimplementedError`
- `requestPermission()` → placeholder
- `getToken()` → placeholder for FCM device token
- `onMessage()` → placeholder for foreground notification handling

### What It Would Do (When Implemented)
- Register device for push notifications
- Store FCM token in `users/{uid}.fcmToken`
- Receive notifications when:
  - Admin updates a stall the user favorited
  - A report the user submitted gets reviewed/resolved
  - Market-wide announcements

### To Implement This
1. Complete the Firebase Cloud Messaging setup in `android/app/build.gradle` and `web/index.html`
2. Fill in the stub methods in `notification_service.dart`
3. Create a Cloud Function (Firebase) to trigger notifications on Firestore writes
4. Handle notification taps → deep link to relevant screen

---

## 4. Google Maps Web Loader

**Files**:
- `lib/core/utils/google_maps_web_loader.dart` — stub (non-web platforms)
- `lib/core/utils/google_maps_web_loader_web.dart` — web implementation

### What It Does
- On web platform only, dynamically injects the Google Maps JavaScript API script into `index.html` at runtime
- Uses an async `Completer` with `onLoad` callback + 10-second safety timeout
- Called in `main()` before `runApp()` to ensure maps are ready before any map widget renders

### Why It Exists
Google Maps Flutter on web requires the JavaScript API to be loaded before the `GoogleMap` widget initializes. Rather than hardcoding the API key in `index.html`, the app loads it dynamically from the `.env` file for security.

### API Key
- `GOOGLE_MAPS_API_KEY` from `.env`
- Also configured in `android/app/src/main/AndroidManifest.xml` for Android

---

## 5. Stall Utilities

**File**: `lib/core/utils/stall_utils.dart`

### What It Does
- Calculates whether a stall is currently **open or closed** based on:
  1. Current time in **Philippine Standard Time (UTC+8)**
  2. Whether today's day name is in the stall's `daysOpen` array
  3. Whether current time is between `openTime` and `closeTime`
- Returns a boolean or a status string for UI display

### Used By
- Map markers (color: green = open, red = closed)
- Stall list status badges
- Stall detail sheet operating hours display
- AI chatbot system prompt (to answer "what's open now?")

---

## 6. App Secrets

**File**: `lib/core/constants/app_secrets.dart`

### What It Does
- Reads API keys from `.env` file (loaded by `flutter_dotenv`)
- Provides typed getters for each secret
- Includes validation: `AppSecrets.isConfigured` and `AppSecrets.missingKeys`

### Available Secrets

```dart
AppSecrets.geminiApiKey        // GEMINI_API_KEY
AppSecrets.googleMapsApiKey    // GOOGLE_MAPS_API_KEY
AppSecrets.cloudinaryCloudName // CLOUDINARY_CLOUD_NAME
AppSecrets.cloudinaryApiKey    // CLOUDINARY_API_KEY
AppSecrets.cloudinaryApiSecret // CLOUDINARY_API_SECRET
AppSecrets.cloudinaryPreset    // CLOUDINARY_UPLOAD_PRESET
AppSecrets.cloudinaryUrl       // CLOUDINARY_URL
```

---

*Next: [Part 10 — Environment & Deployment →](./10-ENVIRONMENT-AND-DEPLOYMENT.md)*
