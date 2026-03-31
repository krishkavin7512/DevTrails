# RainCheck Mobile — Flutter Setup Guide
**Windows 11 | VS Code | Connects to localhost:5001 + localhost:8000**

---

## What You're Building

A Flutter Android app that talks to the existing RainCheck backend. The web app stays as-is. This is a separate client — same APIs, same MongoDB, different frontend.

---

## Step 1 — Install Flutter SDK

1. Download the latest stable Flutter SDK for Windows:
   https://docs.flutter.dev/get-started/install/windows/mobile

2. Extract the zip to `C:\flutter` (do NOT put it in `C:\Program Files` — spaces in paths break things)

3. Add Flutter to your PATH:
   - Search "Environment Variables" in Windows Start
   - Under "System Variables" → select `Path` → Edit → New
   - Add: `C:\flutter\bin`
   - Click OK on all dialogs

4. Open a **new** terminal and verify:
   ```
   flutter --version
   ```
   Should print something like `Flutter 3.x.x • channel stable`

5. Run the doctor:
   ```
   flutter doctor
   ```
   We'll fix whatever it reports in the steps below.

---

## Step 2 — Android Studio + SDK

1. Download Android Studio (if not installed):
   https://developer.android.com/studio

2. During install, make sure these are checked:
   - Android SDK
   - Android SDK Platform
   - Android Virtual Device (AVD)

3. After install, open Android Studio → More Actions → SDK Manager
   Install these SDK packages (under SDK Platforms tab):
   - Android 14.0 (API 34) — check the box

4. Under SDK Tools tab, make sure these are installed:
   - Android SDK Build-Tools 34
   - Android Emulator
   - Android SDK Platform-Tools
   - Intel x86 Emulator Accelerator (HAXM) — if your CPU supports it

5. Accept Android licenses (run this in terminal, type `y` to everything):
   ```
   flutter doctor --android-licenses
   ```

---

## Step 3 — Create Android Emulator

1. Open Android Studio → More Actions → Virtual Device Manager
2. Click "Create Device"
3. Select: **Pixel 6** → Next
4. Select: **API 34 (Android 14)** → Download if not already downloaded → Next
5. Name it `Pixel6_RainCheck` → Finish
6. Click the Play button to start the emulator and verify it boots

---

## Step 4 — VS Code Extensions

Open VS Code, go to Extensions (Ctrl+Shift+X), install:

- **Flutter** (by Dart Code) — flutter.flutter
- **Dart** (by Dart Code) — dart-code.dart-code
- **Pubspec Assist** — jeroen-meijer.pubspec-assist (speeds up adding packages)
- **Better Comments** — aaron-bond.better-comments

After installing Flutter extension, VS Code will prompt to set the Flutter SDK path.
Point it to: `C:\flutter`

---

## Step 5 — Firebase Project Setup

You need Firebase for push notifications (FCM) and optional auth.

1. Go to https://console.firebase.google.com
2. Click "Add project" → Name it `raincheck-mobile` → Continue
3. Disable Google Analytics for now (you can enable later) → Create project

**Enable services:**

- Left sidebar → Build → **Authentication** → Get Started
  - Enable: Email/Password
  - Enable: Google Sign-In (you'll need a support email)

- Left sidebar → Build → **Cloud Messaging** — it's already enabled by default

**Register your Android app:**

- Project Overview → Add app → Android icon
- Package name: `com.raincheck.mobile`
- App nickname: `RainCheck Mobile`
- Download `google-services.json`
- Place it at: `mobile/android/app/google-services.json`

---

## Step 6 — Google Maps API Key

1. Go to: https://console.cloud.google.com
2. Create a new project (or use existing) → name it `raincheck`
3. APIs & Services → Enable APIs → search "Maps SDK for Android" → Enable
4. APIs & Services → Credentials → Create Credentials → API Key
5. Copy the key (looks like `AIzaSy...`)
6. Restrict it: Application restrictions → Android apps → Add your package name `com.raincheck.mobile`

---

## Step 7 — Razorpay Test Keys

1. Sign up at: https://dashboard.razorpay.com
2. Make sure you're in **Test Mode** (toggle in top-right)
3. Settings → API Keys → Generate Test Key
4. You'll get:
   - Key ID: `rzp_test_xxxxxxxxxxxx`
   - Key Secret: (shown once — copy it)

---

## Step 8 — Environment Variables in Flutter

Flutter doesn't support `.env` files natively the same way Node does.
The secure pattern is `--dart-define` at run time.

Create `mobile/.env` (gitignored — never committed):
```
MAPS_API_KEY=AIzaSy...
RAZORPAY_KEY_ID=rzp_test_...
API_BASE_URL=http://10.0.2.2:5001/api
ML_BASE_URL=http://10.0.2.2:8000/api
```

> **Why 10.0.2.2?** Android emulator uses `10.0.2.2` to reach your Windows localhost.
> On a real device, use your machine's local IP (e.g., `192.168.1.x`).

In Flutter code, access via:
```dart
const apiUrl = String.fromEnvironment('API_BASE_URL');
```

Run with:
```
flutter run --dart-define-from-file=.env
```

---

## Step 9 — Create the Flutter Project

Inside `k:/DevTrails/mobile`, run:
```
flutter create . --org com.raincheck --project-name raincheck_mobile
```

This scaffolds the project in the current folder.

---

## Step 10 — pubspec.yaml (full dependencies)

Replace the `dependencies` section in `pubspec.yaml` with:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Firebase
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  firebase_messaging: ^15.1.3
  google_sign_in: ^6.2.1

  # Maps & Location
  google_maps_flutter: ^2.9.0
  geolocator: ^13.0.1
  geocoding: ^3.0.0

  # Payments
  razorpay_flutter: ^1.3.7

  # Notifications
  flutter_local_notifications: ^18.0.1

  # Sensors (crash detection)
  sensors_plus: ^6.1.0

  # Device Info (fraud detection)
  device_info_plus: ^11.1.1

  # Networking
  dio: ^5.7.0
  http: ^1.2.2

  # State Management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Charts
  fl_chart: ^0.69.0

  # Storage
  shared_preferences: ^2.3.2
  flutter_secure_storage: ^9.2.2

  # UI Utilities
  intl: ^0.19.0
  url_launcher: ^6.3.1
  image_picker: ^1.1.2
  cached_network_image: ^3.4.1
  shimmer: ^3.0.0
  lottie: ^3.1.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  riverpod_generator: ^2.4.3
  build_runner: ^2.4.12
```

After editing, run:
```
flutter pub get
```

---

## Step 11 — Add google-services.json to Android build

Open `mobile/android/app/build.gradle` and at the very bottom add:
```gradle
apply plugin: 'com.google.gms.google-services'
```

Open `mobile/android/build.gradle` and in the `dependencies` block add:
```gradle
classpath 'com.google.gms:google-services:4.4.2'
```

---

## Step 12 — Add Maps API Key to AndroidManifest

Open `mobile/android/app/src/main/AndroidManifest.xml`
Inside `<application>` add:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_MAPS_API_KEY"/>
```

---

## Step 13 — Verify Backend Connectivity

With your backend running (`npm run dev` in the server folder), test from terminal:
```
curl http://localhost:5001/api/health
```
Should return: `{"success":true,"data":{"status":"ok"}}`

From the emulator, the same request goes to `http://10.0.2.2:5001/api/health`.
We'll write a connectivity test in the Flutter app to confirm this.

---

## Step 14 — CORS Update for Flutter

The backend currently allows `CLIENT_URL=http://localhost:3000`.
Flutter emulator requests come from `http://10.0.2.2` — add this to CORS.

In `server/src/index.ts`, update the CORS origin to include both:
```typescript
origin: [
  'http://localhost:3000',
  'http://10.0.2.2',
  'http://10.0.2.2:3000',
],
```

---

## Step 15 — Run the App

Start the emulator (or plug in a real Android device with USB debugging on).

```
# From k:/DevTrails/mobile
flutter run --dart-define-from-file=.env
```

You should see the default Flutter counter app launch.
That confirms the toolchain is working — we replace it with RainCheck next.

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `flutter: command not found` | PATH not set — restart terminal after adding to PATH |
| `Unable to locate Android SDK` | Set SDK path: Android Studio → SDK Manager → copy path → `flutter config --android-sdk "C:\Users\...\AppData\Local\Android\Sdk"` |
| `Gradle build failed` | Run `flutter clean` then `flutter pub get` then try again |
| `HAXM not installed` | Enable Intel Virtualization in BIOS, then install HAXM from SDK Manager |
| `Google Maps blank/grey` | API key missing or wrong package name in Cloud Console restriction |
| `Firebase not initialized` | `google-services.json` in wrong folder — must be `android/app/` not `android/` |
| Emulator can't reach backend | Use `10.0.2.2` not `localhost` in API URLs for emulator |
| Real device can't reach backend | Use your machine's LAN IP (`ipconfig` → IPv4 address) |

---

## Checklist Before We Start Coding

- [ ] `flutter doctor` shows no critical errors (Android toolchain green)
- [ ] Emulator boots to home screen
- [ ] `flutter run` launches default app on emulator
- [ ] `google-services.json` placed in `android/app/`
- [ ] Backend running and reachable at `http://localhost:5001/api/health`
- [ ] `flutter pub get` completes without errors

Once all boxes are checked, we move to Prompt 1: building the app structure.
