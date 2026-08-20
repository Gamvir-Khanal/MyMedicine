<div align="center">

# 💊 Smart Medicine Cabinet

**A full-featured Flutter medication management app — reminders, expiry tracking, dose history, cloud sync, and a full-screen alarm engine.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.3+-0175C2?logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-FFCA28?logo=firebase)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-Private-red)](#)
[![Version](https://img.shields.io/badge/Version-1.0.0-brightgreen)](#)

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Screenshots & Screens](#-screens)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
- [Firebase Setup](#-firebase-setup)
- [Data Storage Strategy](#-data-storage-strategy)
- [Notification & Alarm Engine](#-notification--alarm-engine)
- [Authentication](#-authentication)
- [Key Services](#-key-services)
- [Environment Notes](#-environment-notes)
- [Known Lint Notes](#-known-lint-notes)

---

## 🌟 Overview

**Smart Medicine Cabinet** is a cross-platform Flutter application designed to help users never miss a dose, track medicine stock, get expiry warnings, and manage their full medication history — all synced securely to the cloud when signed in.

The app supports two modes:
- **Guest mode** — all data stored locally in SQLite, no account needed.
- **Signed-in mode** — all data stored in Firebase Firestore, synced across devices.

---

## ✨ Features

### 💊 Medicine Management
- Add medicines with name, dosage form, quantity, expiry date, and custom instructions
- Supports 8 dosage forms: Tablet, Capsule, Syrup, Injection, Drops, Ointment, Inhaler, Other
- Medicine detail screen with full info, edit, and delete capabilities
- Quantity decrement tracking when a dose is logged

### ⏰ Smart Reminder Engine
- **Daily reminders** — fires every day at a set time
- **Specific days** — pick custom days of the week (Mon–Sun)
- **One-time reminders** — schedule for a specific date & time
- Toggle reminders on/off individually
- Custom ringtone support — pick any audio file from device storage
- Escalating alarm: if dismissed/snoozed, re-fires at configurable intervals (default every 5 min, up to 3 times)

### 🔔 Full-Screen Alarm Screen
- Launches on top of lock screen / other apps (requires overlay permission)
- Displays medicine name, dosage, and alarm time
- Actions: **Take** ✅ | **Snooze** 😴 | **Miss** ❌
- Shows emergency contact info directly on the alarm screen
- Battery optimization bypass request for reliable background delivery

### 📅 Expiry Tracking
- Automatic expiry alert notifications at **30 days**, **7 days**, and **1 day** before expiry
- Dedicated expiry screen listing all expired / expiring-soon medicines
- Visual status badges on medicine cards

### 📦 Stock & Refill Alerts
- Low stock threshold per medicine (default: ≤ 5 units)
- Instant refill reminder notification when stock drops below threshold
- Dedicated low-stock screen

### 📊 Dose History & Calendar
- Full dose log with taken / missed / snoozed statuses
- Calendar heatmap view showing statuses per day for any month
- Filter history by day

### 🌍 Timezone Awareness
- Auto-detects device timezone on app resume
- Reschedules all active reminders when timezone changes are detected

### 🔐 Authentication
- **Email & Password** signup/login with real-time validation
- **Google Sign-In** (OAuth2 via Firebase)
- Password strength indicator (weak / fair / strong / very strong)
- Password reset via email
- Secure sign-out (clears Firebase Auth + Google session)

### 🚨 Emergency Contact
- Set an emergency contact (name + phone number)
- Shown prominently on the full-screen alarm screen
- Prompted during the registration onboarding flow
- Editable anytime from Settings

### ☁️ Cloud Sync (Firestore)
- All data (medicines, reminders, dose logs) syncs to Firestore under the user's UID
- Automatic reload on sign-in, automatic clear on sign-out
- Guest data stays local — no accidental mixing
- Batch deletes for cascade reminders on medicine removal

### 🎨 UI / UX
- Light & Dark theme support with a custom green-toned palette
- Animated gradient buttons, glassmorphic cards, ambient background orbs
- Smooth transitions, floating snack bars, full Material 3 design
- Responsive layouts for phones and tablets

---

## 📱 Screens

| Screen | Description |
|--------|-------------|
| `LoginScreen` | Email/password login + Google OAuth + forgot password |
| `RegisterScreen` | Account creation with password strength meter & terms |
| `EmergencyContactSetupScreen` | Post-registration onboarding to set emergency contact |
| `HomeScreen` | Dashboard with stats, quick actions, expiry & low-stock widgets |
| `MedicineListScreen` | Full sortable list of all medicines |
| `MedicineDetailScreen` | View, edit, delete a medicine + its reminders |
| `AddEditMedicineScreen` | Add or update a medicine with form validation |
| `RemindersScreen` | All reminders across all medicines |
| `DoseHistoryScreen` | Calendar + log view of dose activity |
| `ExpiryScreen` | Medicines expiring soon or already expired |
| `LowStockScreen` | Medicines below refill threshold |
| `AlarmRingScreen` | Full-screen alarm with take / snooze / miss actions |
| `SettingsScreen` | Emergency contact + alarm escalation configuration |

---

## 🏗 Architecture

The app uses a **Provider-based reactive architecture** with a clean separation of concerns:

```
┌─────────────────────────────────────────┐
│                  UI Layer                │
│     Screens ──── Widgets                │
└────────────────────┬────────────────────┘
                     │ reads / calls
┌────────────────────▼────────────────────┐
│              Provider Layer              │
│  MedicineProvider  ReminderProvider      │
│  DoseLogProvider   ThemeProvider         │
└──────────┬──────────────────┬───────────┘
           │ guest            │ logged-in
┌──────────▼───────┐ ┌────────▼──────────┐
│  DatabaseService │ │ FirestoreService  │
│    (SQLite)      │ │  (Cloud Firestore) │
└──────────────────┘ └───────────────────┘
```

### Auth-Aware Data Flow

```
AuthStateChanges (Firebase)
       │
       ├── Sign-in  → loadMedicines() + loadReminders() + loadLogs()
       │              (reads from Firestore)
       │
       └── Sign-out → clear() all providers
                      + loadMedicines() + loadReminders() + loadLogs()
                        (reads from SQLite for guest session)
```

---

## 🛠 Tech Stack

| Category | Package | Version |
|----------|---------|---------|
| UI Framework | `flutter` | 3.x |
| State Management | `provider` | ^6.1.2 |
| Local Database | `sqflite` | ^2.3.3 |
| Cloud Database | `cloud_firestore` | 6.8.0 |
| Authentication | `firebase_auth` | ^6.5.7 |
| Google Sign-In | `google_sign_in` | ^6.2.2 |
| Firebase Core | `firebase_core` | ^4.13.0 |
| Notifications | `flutter_local_notifications` | ^17.2.1 |
| Audio (Alarm) | `audioplayers` | ^6.1.0 |
| Timezone | `timezone` + `flutter_timezone` | ^0.9.4 / ^3.0.1 |
| File Picker | `file_picker` | ^8.1.2 |
| URL Launcher | `url_launcher` | ^6.3.1 |
| Preferences | `shared_preferences` | ^2.3.0 |
| UUID | `uuid` | ^4.4.0 |
| Date Formatting | `intl` | ^0.19.0 |
| Path Utilities | `path` + `path_provider` | ^1.9.0 / ^2.1.6 |

---

## 📁 Project Structure

```
lib/
├── main.dart                        # App entry point + AuthStateListener
│
├── models/
│   ├── medicine.dart                # Medicine entity (toMap / fromMap)
│   ├── reminder.dart                # Reminder entity (SQLite + Firestore maps)
│   └── dose_log.dart                # DoseLog entity
│
├── providers/
│   ├── medicine_provider.dart       # Medicine state + dual-path CRUD
│   ├── reminder_provider.dart       # Reminder state + dual-path CRUD
│   ├── dose_log_provider.dart       # Dose log state + dual-path CRUD
│   └── theme_provider.dart          # Light / Dark theme persistence
│
├── services/
│   ├── auth_service.dart            # Firebase Auth (email, Google, reset)
│   ├── database_service.dart        # SQLite CRUD (guest mode)
│   ├── firestore_service.dart       # Firestore CRUD (logged-in mode)
│   ├── notification_service.dart    # Local notifications + alarm channel
│   ├── reminder_api_service.dart    # High-level reminder scheduling API
│   └── app_settings_service.dart   # SharedPreferences (contact, escalation)
│
├── screens/
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── emergency_contact_setup_screen.dart
│   ├── home_screen.dart
│   ├── medicine_list_screen.dart
│   ├── medicine_detail_screen.dart
│   ├── add_edit_medicine_screen.dart
│   ├── reminders_screen.dart
│   ├── dose_history_screen.dart
│   ├── expiry_screen.dart
│   ├── low_stock_screen.dart
│   ├── alarm_ring_screen.dart
│   └── settings_screen.dart
│
├── widgets/
│   ├── auth_text_field.dart         # Styled text field for auth screens
│   ├── medicine_card.dart           # Card widget for medicine list items
│   ├── reminder_tile.dart           # Tile widget for reminder list items
│   ├── password_strength_indicator.dart  # Animated password strength bar
│   └── social_auth_button.dart      # Google / Apple sign-in button
│
└── utils/
    ├── app_theme.dart               # Light & dark ThemeData definitions
    └── constants.dart               # App-wide constants (name, forms, thresholds)
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>=3.3.0 <4.0.0`
- Dart `>=3.3.0`
- Android Studio / VS Code with Flutter & Dart plugins
- A Firebase project (see [Firebase Setup](#-firebase-setup))
- Android emulator or physical device (API 21+)

### Clone & Install

```bash
git clone https://github.com/Gamvir-Khanal/MyMedicine.git
cd MyMedicine
flutter pub get
```

### Run

```bash
flutter run
```

> **Tip:** Use a physical Android device for full alarm/notification testing. Emulators may not reliably deliver background alarms.

---

## 🔥 Firebase Setup

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication** → Email/Password and Google providers
3. Enable **Cloud Firestore** (start in test mode, then apply security rules below)
4. Download `google-services.json` and place it at `android/app/google-services.json`
5. *(iOS)* Download `GoogleService-Info.plist` and place it at `ios/Runner/GoogleService-Info.plist`

### Firestore Security Rules

Apply these rules under **Firestore → Rules**:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

> Each user can only read and write their own data under `users/{uid}/...`.

### Firestore Data Structure

```
users/
  └── {uid}/
        ├── medicines/
        │     └── {medicineId}    → Medicine document
        ├── reminders/
        │     └── {reminderId}    → Reminder document
        └── dose_logs/
              └── {logId}         → DoseLog document
```

---

## 🗄 Data Storage Strategy

| Scenario | Storage Used |
|----------|-------------|
| Guest (not signed in) | SQLite (local, persists across restarts) |
| Signed-in user | Cloud Firestore (synced, per-UID) |
| App settings (emergency contact, escalation config) | SharedPreferences (always local) |

**Key rules:**
- Guest data **never** touches Firestore.
- Signed-in data **never** touches SQLite.
- On sign-out, all in-memory provider state is cleared before loading SQLite guest data.
- On sign-in, providers reload from Firestore automatically via `_AuthStateListener` in `main.dart`.

---

## 🔔 Notification & Alarm Engine

### Scheduling Modes

| Mode | Trigger |
|------|---------|
| `daily` | Fires every day at `HH:MM` |
| `specificDays` | Fires on selected days of the week at `HH:MM` |
| `once` | Fires once at a specific `DateTime` |

### Expiry Notifications

Automatically scheduled at:
- **30 days** before expiry
- **7 days** before expiry
- **1 day** before expiry (fires at 09:00 on that day)

### Escalation

If a dose alarm fires and the user doesn't interact:
1. A follow-up alarm fires after `N` minutes (configurable, default **5 min**)
2. Repeats up to `M` times (configurable, default **3 times**)

### Android Permissions Required

| Permission | Purpose |
|-----------|---------|
| `SCHEDULE_EXACT_ALARM` | Fire alarms at precise times |
| `USE_EXACT_ALARM` | Android 13+ exact alarm permission |
| `SYSTEM_ALERT_WINDOW` | Show alarm over lock screen / other apps |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Prevent OS from killing alarms |
| `RECEIVE_BOOT_COMPLETED` | Reschedule alarms after reboot |

---

## 🔐 Authentication

### Flows

```
Register Screen
  ├── Email/Password → Firebase createUserWithEmailAndPassword
  │     └── → EmergencyContactSetupScreen → HomeScreen
  └── Google → GoogleSignIn + Firebase signInWithCredential
        └── → EmergencyContactSetupScreen → HomeScreen

Login Screen
  ├── Email/Password → Firebase signInWithEmailAndPassword → HomeScreen
  ├── Google → GoogleSignIn + Firebase signInWithCredential → HomeScreen
  └── Forgot Password → Firebase sendPasswordResetEmail

HomeScreen (signed in)
  └── Sign Out → Firebase signOut + GoogleSignIn signOut
                 → All providers cleared → Guest mode
```

### Error Handling

All `FirebaseAuthException` codes are converted to human-readable messages by `AuthService.getReadableErrorMessage()`:

| Firebase Code | User Message |
|--------------|-------------|
| `user-not-found` | No account found with this email |
| `wrong-password` / `invalid-credential` | Invalid email or password |
| `email-already-in-use` | Account already exists with this email |
| `weak-password` | Password is too weak |
| `too-many-requests` | Too many attempts, try again later |

---

## ⚙️ Key Services

### `NotificationService`
Singleton that wraps `flutter_local_notifications`. Handles:
- Plugin initialization and timezone setup
- Scheduling daily, specific-day, and one-time notifications
- Full-screen alarm intent + lock-screen bypass via native `MethodChannel`
- Escalation notification chains
- Overlay permission and battery optimization checks

### `ReminderApiService`
High-level facade over `NotificationService`. Providers call this — never `NotificationService` directly. Handles:
- `scheduleReminder(reminder)` — routes to correct scheduling mode
- `cancelReminder(reminder)` — cancels notification + all escalations
- `scheduleExpiryAlerts(medicine)` — schedules 30/7/1-day notices
- `triggerRefillReminder(medicine)` — fires immediate refill alert

### `FirestoreService`
Stateless Firestore CRUD service. All methods require the caller to pass `uid`. Never called for guest users.

### `DatabaseService`
SQLite CRUD service used exclusively for guest sessions.

### `AppSettingsService`
SharedPreferences wrapper for device-local settings:
- Emergency contact (name + phone)
- Alarm escalation toggle, interval, and max count

---

## 🌐 Environment Notes

- **Minimum Android SDK:** 21 (Android 5.0 Lollipop)
- **Target SDK:** Latest stable
- **iOS:** Supported (alarm background behavior may vary)
- **Web / Desktop:** Packages present but not primary targets; notification and alarm features require mobile

---

## 🗒 Known Lint Notes

Running `dart analyze lib/` produces **0 errors**. There are pre-existing `info`-level deprecation warnings from Flutter SDK version drift (e.g. `withOpacity` → `withValues`, `useMaterial3` constructor changes). These do not affect functionality and will be addressed in a future cleanup pass.

---

## 📄 License

This project is private. All rights reserved © 2026 Gamvir Khanal.

---

<div align="center">
Made with ❤️ and Flutter
</div>
