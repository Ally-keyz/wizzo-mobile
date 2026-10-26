# Wizzo Market — Apple App Store release kit

Everything the iOS app needs before it goes to App Store Connect, plus the exact
steps to build, upload and submit it. Android/Play details stay in
[`RELEASE_PREP.md`](RELEASE_PREP.md).

Current version: **1.4.8 (build 33)** — `pubspec.yaml`. Bundle id:
**`app.wizzo.wizzoMarket`**. Apple Developer Program: paid team required.

---

## 1. What was prepared in the code (done)

| Item | Where | Status |
|---|---|---|
| Version bump to 1.4.8+33 | `pubspec.yaml` | ✔ |
| Categories moved from the home rail to a bottom-bar tab (`/categories`) | `bottom_nav.dart`, `app_router.dart`, `home_screen.dart` | ✔ |
| Sign-up "Continue" no longer dead (seller name+email validation crash) | `seller_signup_screen.dart`, `buyer_signup_screen.dart` | ✔ |
| In-app **Delete account** (App Store 5.1.1(v)) | account screen → `DELETE /users/me` (server anonymises the profile, hides listings, revokes refresh tokens) | ✔ |
| **Report user** + **Block user** in chat (guideline 1.2, UGC) | conversation screen ⋮ menu → `POST /reports/user`, `POST /users/me/blocks` | ✔ |
| Privacy manifest (`PrivacyInfo.xcprivacy`) with required-reason APIs + collected data | `ios/Runner/PrivacyInfo.xcprivacy`, added to the Runner target resources | ✔ |
| Usage strings for camera, photos, mic, location | `ios/Runner/Info.plist` | ✔ |
| Export-compliance flag (HTTPS only, no custom crypto) | `ITSAppUsesNonExemptEncryption = false` in `Info.plist` | ✔ |
| `LSApplicationQueriesSchemes` for WhatsApp/mail/tel links | `Info.plist` | ✔ |
| Declared app languages en/fr/rw/de/sw | `CFBundleLocalizations` in `Info.plist` | ✔ |
| App icon set (1024 + all sizes, no alpha) | `ios/Runner/Assets.xcassets/AppIcon.appiconset` | ✔ verify visually |
| Launch screen | `ios/Runner/Base.lproj/LaunchScreen.storyboard` | ✔ |
| Privacy policy / terms pages exist on the web | `/privacy-policy`, `/terms-of-service` | ✔ |

Hard requirements still owned by you:

1. **A Mac** (or a macOS CI) with Xcode 16+ — iOS archives cannot be built on Windows.
2. **Apple team + App Store Connect app record** for `app.wizzo.wizzoMarket`.
3. **Privacy policy URL** — use `https://wizzomarketplace.com/privacy-policy`.
4. **Live Stripe key** before submission if card payments must work in review
   (the repo default is a test key; the server may already supply its own).
5. **Demo account** for the reviewer (see §7).

---

## 2. One-time Apple setup

### 2.1 App ID
1. <https://developer.apple.com/account> → Certificates, Identifiers & Profiles → Identifiers → **+**.
2. Type **App IDs → App**, description "Wizzo Market", bundle id **explicit**:
   `app.wizzo.wizzoMarket`.
3. Capabilities: leave default (no Push, no IAP needed — the app sells physical
   goods and uses external payment methods, which Apple allows under 3.1.3(e)).
4. If you want **Apple Pay** in the app, also:
   - Identifiers → Merchant IDs → **+** → e.g. `merchant.com.wizzomarketplace`.
   - Add the **Apple Pay** capability to the App ID and select that merchant id.
   - Build with `--dart-define=APPLE_PAY_MERCHANT_ID=merchant.com.wizzomarketplace`
     and enable the Apple Pay capability in Xcode for the Runner target
     (adds `com.apple.developer.in-app-payments` to the entitlements).
   - Without these steps Apple Pay stays hidden; cards still work via Stripe.

### 2.2 App Store Connect app
1. <https://appstoreconnect.apple.com> → My Apps → **+** → New App.
2. Platform **iOS**, name **Wizzo Market** (or KATISHA — must be unique on the
   store), primary language English, bundle id `app.wizzo.wizzoMarket`, SKU
   `wizzo-market-ios`, full access.
3. Note the app's Apple ID (numeric) — useful for links.

### 2.3 Signing
1. On the Mac: Xcode → Settings → Accounts → add the Apple ID of the team.
2. Open `mobile/ios/Runner.xcworkspace` (not the `.xcodeproj`).
3. Select the **Runner** target → Signing & Capabilities:
   - Team = your paid team, **Automatically manage signing**.
   - Bundle Identifier = `app.wizzo.wizzoMarket`.
4. Xcode creates the Apple Distribution certificate + provisioning profile.

---

## 3. Build the iOS archive (on macOS)

```bash
cd mobile
flutter pub get
cd ios && pod install && cd ..

flutter build ipa --release \
  --build-name 1.4.8 --build-number 33
  # add --dart-define=APPLE_PAY_MERCHANT_ID=merchant.com.wizzomarketplace if enabled
```

Output: `build/ios/ipa/wizzo_market.ipa` (and the `.xcarchive`). Upload with:

- **Xcode Organizer** — `open build/ios/archive/*.xcarchive`, then
  *Distribute App → App Store Connect → Upload*.
- or **Transporter** app (drag the `.ipa`), or
  `xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios --apiKey … --apiIssuer …`.

If you do not own a Mac, use a macOS CI (Codemagic, GitHub Actions `macos-latest`,
Bitrise): the steps are identical — `flutter build ipa` plus an App Store Connect
API key (App Store Connect → Users and Access → Integrations → App Store Connect API).

Checklist for the archive:
- Version shows **1.4.8 (33)** in App Store Connect after upload.
- No signing warnings; "Upload Symbols" enabled (default via Flutter).
- The archive must be built with the latest public Xcode SDK (Apple rejects old SDKs).

---

## 4. App Store Connect listing (copy/paste drafts)

**Name:** Wizzo Market
**Subtitle (≤30):** Buy & sell across East Africa
**Category:** Shopping (secondary: Lifestyle)
**Age rating:** 12+ (user-generated content + chat, moderated with report/block)
**Price:** Free
**Availability:** Rwanda first, then Kenya/Uganda/Tanzania/Burundi (your call)

**Promotional text (≤170):**
Wizzo is the marketplace for East Africa: shop local sellers, chat in real time,
pay with MoMo, card or cash on delivery, and sell your own products in minutes.

**Description:**
Wizzo Market is a trusted multi-vendor marketplace built for East Africa. Discover
electronics, phones, fashion, beauty, home, groceries, cars and services from
verified local sellers and international stores.

Shop with confidence
• Verified seller badges, ratings and reviews
• Real-time chat with sellers before you buy
• Pay with Mobile Money, Visa/Mastercard, Apple Pay or cash on delivery
• Delivery or local pickup, with order tracking
• Wishlist, follow stores and get notified about new deals

Sell in minutes
• Create your store and list products from your phone
• Manage orders, stock and payouts in the seller dashboard
• Chat directly with buyers and ship with dropshipping support

Built for the region
• Prices in RWF, USD, EUR and more
• English, French, Kinyarwanda, Swahili and German
• Light and dark mode

Questions? Support is one tap away in the app.

**Keywords (≤100):**
marketplace,shopping,buy,sell,kigali,rwanda,east africa,momo,phones,fashion,deals,store

**URLs**
- Support: `https://wizzomarketplace.com/support`
- Marketing: `https://wizzomarketplace.com`
- Privacy policy: `https://wizzomarketplace.com/privacy-policy`
- Terms (in-app/legal): `https://wizzomarketplace.com/terms-of-service`

**Screenshots** (take on a real device or the simulator, light + dark recommended):
- 6.9" iPhone — 1320 × 2868 (required)
- 6.5" iPhone — 1242 × 2688 or 1284 × 2778 (optional but useful)
- 13" iPad — 2064 × 2752 (required **only** if you keep iPad support; see note)

Suggested shots: home with deals → categories tab → product detail with variants →
chat with a seller → checkout payment options → seller dashboard.

> Note: if you do **not** want to support iPad, set *Targeted Device Families* to
> iPhone only (`TARGETED_DEVICE_FAMILY = 1` in Xcode / `project.pbxproj`) and no
> iPad screenshots are needed.

**App icon:** the existing 1024×1024 icon in `AppIcon.appiconset` (no alpha, no
rounded corners — Apple masks it).

---

## 5. App Privacy answers ("nutrition label")

Declare **Data linked to you** (all used for *App Functionality* only, never for
tracking, never sold):

| Category | Detail | Notes |
|---|---|---|
| Contact info | Name, email, phone | account + orders |
| User content | Photos/videos, messages, product listings, store info | chat, listings, proof of payment |
| Identifiers | User ID | backend account id |
| Purchases | Purchase history | orders |
| Location | Coarse location (city/country) | chosen by the user, no GPS tracking |
| Diagnostics | none | no crash/analytics SDK |

- **Tracking:** No. The app has no ad SDKs and does not share data with data brokers.
- **Data deletion:** users delete their account in-app (Account → Delete account);
  the server anonymises the profile and takes listings offline. Deletion requests
  can also be emailed to support.
- **Encryption:** HTTPS in transit. Auth token is stored in `shared_preferences`
  (protected by iOS app sandbox; excluded from Android backup). Recommended
  follow-up: migrate the token to Keychain (`flutter_secure_storage`).

---

## 6. Age rating questionnaire

Answer **Yes** to user-generated content and chat, **Yes** to "users can interact",
**No** to unrestricted web access, **No** to gambling/ads. With in-app reporting
and blocking this normally lands at **12+**.

---

## 7. App Review information (paste into App Store Connect)

**Sign-in required:** Yes — provide a demo account:

- Buyer: create `appreview+buyer@wizzomarketplace.com` / `Review1234!`
  (or use a seeded buyer) and complete a purchase up to the payment step.
- Seller demo (already seeded): `seller01@wizzo.test` / `Password123!`

**Notes for the reviewer:**

> Wizzo Market is a multi-vendor marketplace for physical goods. Payments are
> handled outside Apple's in-app purchase system (guideline 3.1.3(e)): buyers pay
> sellers by Mobile Money, bank transfer, card via Stripe or cash on delivery; the
> app does not sell digital content or subscriptions.
>
> Categories is the second bottom-bar tab. Account → Delete account permanently
> deletes the signed-in account. In a chat, the ⋮ menu lets users report or block
> the other person. Support: support@wizzo.com.

Do **not** ship test Stripe keys to review: card payments fail and reviewers
report it as a bug. Confirm the server returns live keys, or hide the card option
for the review build.

---

## 8. Upload → TestFlight → Submit

1. Upload the archive (§3). Wait 10–30 min for processing in App Store Connect →
   TestFlight.
2. Answer **Export Compliance**: "No" (the app only uses standard HTTPS; already
   declared via `ITSAppUsesNonExemptEncryption=false`).
3. Add yourself as an **internal tester**, install via TestFlight and smoke-test:
   sign-up (buyer + seller), sign-in, categories tab, product → cart → checkout,
   chat/report/block, delete account (use a throwaway account).
4. Back in App Store Connect: create version **1.4.8**, attach build 33, fill
   §4–§7, upload screenshots, save.
5. **Add for Review** → answer the final questions (ads: no; content rights: you
   own/have rights; encryption: no) → **Submit**.
6. Review usually takes 24–48 h. If rejected, fix and upload a new build
   (build number must increase: 1.4.8+34).
7. On approval choose **Manually release** so you control the go-live moment.

---

## 9. Known risks / last checks before submitting

- **Stripe test key in `AppConfig`**: card payments will not charge real money.
  Either point the build at live keys or hide the card tile for review.
- **Apple Pay**: only works after the merchant id + entitlement steps in §2.1.
  Without them the Apple Pay tile is hidden (it is gated on
  `APPLE_PAY_MERCHANT_ID`), which is fine.
- **Account deletion**: backend must be deployed with `DELETE /users/me`, plus
  `POST /reports/user` and `POST /users/me/blocks` (server commit for this release).
- **Chat/block**: blocking hides the thread and refuses new messages in both
  directions; reported users land in the `reports` collection for moderation.
- **Placeholder copy**: no Lorem Ipsum/“coming soon” screens should be reachable in
  the main flows (some seller "coming soon" sheets exist — reviewers tolerate them
  when clearly secondary, but remove if asked).
- **Privacy policy** must mention account deletion and chat/report data.
- **iPad**: either ship iPad screenshots or switch to iPhone-only.
- **Name**: "Wizzo Market" must be available on the App Store; otherwise use the
  KATISHA listing name already planned for Google Play.
- **Version**: build number must increase for every upload (33 now).
