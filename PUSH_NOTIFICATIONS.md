# Device notifications (Firebase Cloud Messaging)

The app can show real OS notifications for marketplace events, including when a
seller publishes a new product. The code is already wired up; this page lists
the credentials and console steps needed to turn it on.

Without Firebase credentials the app still builds and runs normally. Push is
simply skipped (`PushNotificationService.bootstrap()` logs and continues).

## How it works

- On sign-in the app asks for the OS notification permission, obtains an FCM
  token and posts it to `POST /auth/fcm-token`.
- Logout calls `DELETE /auth/fcm-token` and deletes the local token, so a shared
  device stops receiving the previous account's notifications.
- `POST /products` with `status: "active"` (or a draft that is later changed to
  `active`) makes the backend announce the listing. It stores an in-app
  notification and sends an FCM multicast to every active user with a token.
  Drafts never announce.
- Foreground messages are displayed through `flutter_local_notifications`
  (Android channel `wizzo_new_products`). Background/terminated messages are
  shown by the OS using the same channel and `@drawable/ic_launcher_foreground`.
- Tapping a notification opens the product, order, conversation, shop or the
  notification centre, depending on its data payload.

## 1. Firebase project

1. Create a project at <https://console.firebase.google.com>.
2. Add an **Android** app with package name `app.wizzo.wizzo_market`.
   - Register the release SHA-1/SHA-256 from `RELEASE_PREP.md` (section 2) if
     Google Sign-In is also configured.
   - Download `google-services.json` into `mobile/android/app/`.
3. Add an **iOS** app with the Runner bundle identifier.
   - Download `GoogleService-Info.plist` into `mobile/ios/Runner/` and add it to
     the Runner target in Xcode (do not copy it into the bundle resources only).
   - In Xcode enable **Push Notifications** and **Background Modes → Remote
     notifications** for the Runner target.
   - Upload the APNs auth key (`.p8`) under Firebase → Project settings → Cloud
     Messaging.
4. Both credential files are gitignored; hand them over out of band.

The Gradle Google Services plugin is applied automatically by
`android/app/build.gradle.kts` as soon as `google-services.json` exists, so no
build-script change is needed after dropping the file in.

## 2. Backend service account

1. Firebase console → **Project settings → Service accounts → Generate new
   private key**. This downloads a JSON file.
2. Set these variables in the server environment (see `server/.env.example`):

   ```dotenv
   FIREBASE_PROJECT_ID=<project id>
   FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
   FIREBASE_CLIENT_EMAIL=<service account email>
   ```

   Keep the `\n` escapes on a single line in hosted environments (Render,
   Docker, etc.); the server converts them to real newlines.

## 3. Verify

1. Install a build that contains `google-services.json` on a physical device.
2. Sign in and accept the notification permission. Confirm the token is stored:
   `db.users.findOne({ email: "..." }, { fcmTokens: 1 })`.
3. As a seller, publish a product with at least one photo. A notification
   titled **New on Wizzo** should appear on every signed-in device, including
   the seller's own device.
4. Repeat while the app is foregrounded, backgrounded and terminated. The
   foreground copy is posted by the app; the other two by the OS.

## Troubleshooting

- **No token / `Firebase is not configured`** — credentials missing or the
  server env vars are empty. Re-check step 2 and restart the server.
- **Notifications work in foreground only** — the Android channel is missing or
  the OS permission was denied. Check **Settings → Apps → Wizzo Market →
  Notifications**.
- **No notification on iOS** — the APNs key, Push Notifications capability, or
  `GoogleService-Info.plist` target membership is missing.
- **Stale device** — FCM reports unregistered tokens, and the backend removes
  them automatically after the next broadcast.
