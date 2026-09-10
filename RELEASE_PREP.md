# Wizzo Market — Google Play Release Preparation

Prepared for the Android app in this repo (package `app.wizzo.wizzo_market`).
Store listing **app name: KATISHA** (owner's choice), app label stays "Wizzo Market".

---

## 1. Build verified (✔ done in this session)

| Item | Value | Status |
|---|---|---|
| Flutter | 3.38.5 stable (Dart 3.10.4) | ✔ |
| AGP / Gradle / Kotlin | 8.11.1 / 8.14 / 2.2.20 (JDK 17 Temurin) | ✔ compatible |
| minSdk / targetSdk / compileSdk | 24 / **36** / 36 | ✔ meets Play API 36 requirement |
| Application ID | `app.wizzo.wizzo_market` (real, keep) | ✔ |
| Version | versionCode 12, versionName 1.1.0 | ✔ keep |
| Permissions | INTERNET + ACCESS_NETWORK_STATE + WAKE_LOCK (transitive), no others | ✔ minimal |
| Cleartext traffic | blocked (network_security_config) | ✔ |
| Backup rules | auth prefs excluded on Android ≤11 (backup_rules) and 12+ (data_extraction_rules) | ✔ |
| Firebase / FCM | none | ✔ not required |
| Release signing | `key.properties` + `wizzo-upload.jks` (both gitignored); signed AAB uses upload key `CN=Wizzo Market, O=Wizzo`, 4096-bit RSA, valid to 2054 | ✔ |
| App Bundle | `build/app/outputs/bundle/release/app-release.aab` (49.1 MB, 51,536,714 bytes) | ✔ built + verified |
| Manifest in AAB | package correct, vc=12, vn=1.1.0, target=36, non-debuggable, label "Wizzo Market" | ✔ |
| Tests | `flutter analyze` (0 errors, 63 info-level only) + `flutter test` → **all 27 pass** | ✔ |

## 2. Release AAB location & credentials

- **AAB:** `mobile/build/app/outputs/bundle/release/app-release.aab` (49.1 MB)
- Signing must NEVER be committed: `android/key.properties` and `android/keystore/wizzo-upload.jks` are gitignored (verified with `git check-ignore`).
- Only the placeholder template `android/key.properties.example` is tracked. Keep the real file safe and backed up — losing it = losing the ability to upload updates.
- Keystore cert SHA-256 (used to register upload key in Play Console):
  `73:A4:47:A0:28:C1:C0:99:46:F9:3E:DB:CF:80:F6:17:51:0A:B3:D7:D2:2B:64:84:24:95:39:6B:ED:1D:78:F8`
- SHA-1 (needed for Firebase / Google Sign-In OAuth):
  `71:22:93:E7:FD:C2:AD:93:41:80:04:48:4A:22:39:7B:86:39:37:84`

## 3. Configuration to RE-CONFIRM for the production build

The AAB above is built with the app's **defaults**. Before the actual Play release build, run
`flutter build appbundle --release` again with the correct `--dart-define` values:

| Dart-define | Default in code | Notes / needed for |
|---|---|---|
| `API_BASE_URL` | `https://api.wizzomarketplace.com/api/v1` (confirmed) | Production API — now the code default. Only pass this define if you ever need to point at staging. |
| `GOOGLE_ANDROID_CLIENT_ID` | empty | Required for Chrome-based Google Sign-In on Android |
| `GOOGLE_SERVER_CLIENT_ID` | empty | Required so Android OAuth works against the backend |
| `MAPTILER_KEY` | empty | Map tiles for delivery-address map |

Without these, Google Sign-In and the map will not work in the released build.. The values are build-time and must be passed on the build machine; they are not present in the repo (no secrets in `git`).

## 4. DATA SAFETY — Play store form answers (Phase 7)

Data table ─ category / type / collected / shared / encrypted / deleted:

| Category | Type | Collected? | Required? | Shared | Encrypted in transit | Deleted |
|---|---|---|---|---|---|---|
| App functionality | Contact info (email, phone) | ✔ | ✔ | No | ✔ HTTPS | On request |
| App functionality | User content (listings, reviews, store info) | ✔ (user-generated) | No | No | ✔ | On request / listing removal |
| App functionality | Messages (seller chat) | ✔ | No | No | ✔ | On request |
| App functionality | Other user-generated content (profile photo, proof-of-payment images, videos) | ✔ | No | No (Cloudinary storage only) | ✔ | On request |
| Personal info | Name, email, phone, user id | ✔ | ✔ | No | ✔ | On request |
| Personal info | Other identifiers (id from backend) | ✔ | ✔ | No | ✔ | On request |
| Financial info | **none** (payments are manual / pay-direct seller; app never asks card/bank of the buyer) | ✘ | — | — | — | — |
| Location | **none from device GPS** (no GPS permission). City/country defaults to Kigali; user may pick a city; optional lat/lng only if an address is geocoded to send that address | limited | No | No | ✔ | On request |
| Photos & videos | Only images/videos the user explicitly picks (image_picker) | ✔ | No | No (Cloudinary) | ✔ | On request |
| App activity | Search terms (only forwarded to OSM/photon autocomplete, not stored by app) | ✘ (forwarded only) | — | OSM — do not collect | ✔ | — |
| Device/other identifiers | **none** (no analytics, no crashreporting, no ad SDKs, no FCM) | ✘ | — | — | — | — |
| Health / contacts / calendar / biometrics | none | ✘ | — | — | — | — |

Third-party SDKs present: `google_sign_in` (Google account), Cloudinary (seller image upload, server-signed — `upload_service.dart`), socket.io (chat/notifications), OpenStreetMap photon/nominatim (place search), open.er-api (currency rates), MapTiler/Carto (map tiles). All network traffic HTTPs (cleartext blocked).

Security/ops details to state in the console:
- Data encryption: in transit (HTTPS). At rest: auth token stored in `shared_preferences` (plaintext XML) but **excluded from Android backups** on both Android ≤11 and 12+; recommend migrating auth token to `flutter_secure_storage` (Keystore) as a future hardening item — not blocking release.
- Data deletion: provide account-deletion path (user accounts → backend must support account deletion endpoint; if not, document manual deletion process for the console's "data deletion" declaration).

Suggested Play understanding: disclosures mirror the table above; the app does **not** collect device ID, precise location, health, financial, or browsing-history data, and does **not** sell data.

## 5. Store listing (Phase 8) — placeholder kit (name: KATISHA)

- **App name:** Katisha
- **Short description (80 char):** "Buy & sell anything in Kigali — chat, order, pay on delivery." (tweak to taste)
- **Full description:** mention markets (electronics, phones, fashion, home, cars, services), seller storefronts & verification, real-time chat, live orders, multi-currency (RWF/USD), French/Kinyarwanda/Swahili support, pay-on-delivery + MoMo/bank for sellers.
- **Category:** Shopping (primary). Audience: Rwanda + East Africa.
- **Assets needed (Create Play listing page):**
  - Icon: existing `mipmap/ic_launcher` — 512×512 PNG (Play requires 512×512, 32-bit) recommended; keep placeholder if not final.
  - Feature graphic: 1024×500 PNG.
  - Phone screenshots: 1 minimum (UK or US market), recommend 4–8 for phones + 1 tablet (min 1200×1600 or 2400×1600 or 1920×1080).
  - Video promo: optional (YouTube URL), ≤ 15 min.
- **Play footer fields:** contact email, website, **Privacy Policy URL — REQUIRED, ask owner to supply** (e.g. published at `wizzomarketplace.com/privacy`), content rating questionnaire (likely "Everyone"/"Everyone 10+" given no mature content), target countries (Rwanda first), price + Google Play auto-signing acceptance.

## 6. Google Play Console checklist (Phase 11) — manual steps

1. `accounts.google.com` → Google Play Console → Create app (name **Katisha**, type App, free/paid, declare whether it's an ad-supported game — no).
2. Set up **App signing**: Play App Signing (recommended). Provide upload certificate (the AAB's upload cert above) or let Google generate; **verify the upload keystore matches what Firebase OAuth expects** (see updated SHA-1 in Firebase console, §3).
3. Upload the AAB from §2 for each release.
4. Fill Data safety form per §4 (required for Play to accept).
5. Fill Store listing (§5), including privacy policy URL.
6. Complete content rating questionnaire → get rating certificate.
7. Verify the app hasn't declared ads (no ad SDKs present).
8. Set up **closed testing** while doing review (§7) — first releases on Play must go through a testing track.
9. Accept Google Play App Signing agreement, confirm no "invalid target API 36" / "missing declarations" issues under **Policy and programs**.
10. Create a **production release** with the verified AAB once testing approval lands.

## 7. Closed testing (Phase 12)

1. Play Console → Setup → Testing tracks → **Closed testing**.
2. Create a track; add tester email list (Google Groups recommended); provide opt-in URL (or Google Play link) to testers.
3. Upload the AAB to the closed track; set release notes (keep versionCode rising, see §8).
4. If the app was previously on a "Play Academy" or internal track flow, ensure the new release passes review for the closed track; 20+ testers 14 days is the old public-review rule — with Play updates, typical path is: internal → closed → open → production; check current policy for "production access" requirements.
5. Collect feedback (pre-production releases can include crash free user percentage in the Console).

## 8. Versioning advice (engineer-use)

Keep `versionCode` strictly increasing for every upload (`12` used). Suggest 1.1.0+12 → next release 1.1.1+13. Change name/features → bump `versionName`.

## 9. Final report (Phase 13)

- Project state: **release-ready in code; publishing is manual in Play Console**.
- All versions/SDKs, signing, AAB path, data-safety answers, store-listing kit, console checklist, testing flow above.
- Open items (non-code blockers):
  - Privacy policy URL (owner).
  - Supply Google OAuth client IDs + MapTiler key for the *final* release build (owner/SI).
  - Confirm account/data deletion endpoint exists on backend (owner/backend) or document manual deletion.
  - Confirm they opted for Google Play App Signing (recommended).
- Security notes: no secrets are in the repo; keystore + key.properties must stay local/backed up; auth token is not encrypted at rest (recommended: `flutter_secure_storage` follow-up).