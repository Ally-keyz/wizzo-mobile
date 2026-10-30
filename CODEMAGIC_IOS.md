# Codemagic → App Store Connect (iOS)

This is the operational checklist for the `wizzo-ios-workflow` in
[`codemagic.yaml`](codemagic.yaml). The pipeline builds a signed `.ipa`, uploads
it to App Store Connect and submits it to TestFlight.

## Why the previous build failed

```
No valid code signing certificates were found
No development certificates available to code sign app for device deployment
```

`codemagic.yaml` downloaded the certificate and provisioning profile, but never
created/unlocked a signing keychain or imported the certificate into it, so
`flutter build ipa` found no identity to sign with. The Xcode project also
hard-coded `CODE_SIGN_IDENTITY[sdk=iphoneos*] = "iPhone Developer"`, which forces
a *development* identity even for an App Store archive.

Fixed in this repo:

- `keychain initialize` + `keychain add-certificates` before
  `xcode-project use-profiles` and before the archive.
- Removed the hard-coded `iPhone Developer` identity from
  `ios/Runner.xcodeproj/project.pbxproj`.
- Raised the iOS deployment target to **15.0** (Xcode/Flutter minimum).
- Kept CocoaPods (`ios/Podfile`) and added an explicit `pod install` step; the
  project is **not** migrated to Swift Package Manager, so removing the Podfile
  would break the build.
- Set the target device family to **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`)
  so App Review does not require iPad screenshots/UI.
- Version pinned in `pubspec.yaml` (`1.4.12+43`). Bump the build number before
  every upload.

## 1. App Store Connect (one-time)

1. **App ID** — developer.apple.com → Certificates, Identifiers & Profiles →
   Identifiers → `+` → App IDs → App. Use the explicit bundle ID
   **`app.wizzo.wizzoMarket`** (exactly as in the Xcode project).
2. **App record** — appstoreconnect.apple.com → My Apps → `+` → New App:
   - Platform: iOS
   - Bundle ID: `app.wizzo.wizzoMarket`
   - SKU: `wizzo-market-ios`
3. **API key** — App Store Connect → Users and Access → Integrations →
   App Store Connect API → `+`. Access level **App Manager**. Download the
   `AuthKey_XXXXXXXXXX.p8` file (only downloadable once). Note the **Key ID**
   and the **Issuer ID**.

## 2. Codemagic environment variables

Codemagic → your app → Environment variables → create/select the group
**`apple store`** (the name must match `codemagic.yaml`) and add:

| Variable | Value | Secret |
|---|---|---|
| `APP_STORE_CONNECT_PRIVATE_KEY` | full contents of `AuthKey_XXXXXXXXXX.p8` | yes |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | Key ID from App Store Connect | no |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID from App Store Connect | no |
| `CERTIFICATE_PRIVATE_KEY` | PEM private key used for the Apple Distribution certificate | yes |

`CERTIFICATE_PRIVATE_KEY` is required so Codemagic can create (or re-use) the
Apple Distribution certificate for the team. Generate one with:

```bash
ssh-keygen -t rsa -b 2048 -m PEM -f ios_distribution_private_key -q -N ""
```

Keep the `.p8` and the private key safe and never commit them.

> Alternatively you can store the certificate and App Store provisioning
> profile under **Code signing identities** and use Codemagic's `ios_signing`
> block. The CLI flow above is already wired up and needs no extra uploads.

### App Store Connect API key stored as an integration

If you added the API key under **Team settings → Integrations → App Store
Connect** instead of pasting it into the `apple store` group, Codemagic does
**not** inject it automatically. Name the integration in `codemagic.yaml`:

```yaml
    environment:
      integrations:
        app_store_connect: <integration name>
```

That exposes `APP_STORE_CONNECT_PRIVATE_KEY`, `APP_STORE_CONNECT_KEY_IDENTIFIER`
and `APP_STORE_CONNECT_ISSUER_ID`. `CERTIFICATE_PRIVATE_KEY` still has to live
in the `apple store` group.

## 3. Run the build

Codemagic → application → **Start new build** → branch/commit → workflow
**Wizzo Market iOS – App Store**.

The workflow:

1. `flutter pub get`
2. `pod install`
3. `flutter analyze --no-fatal-infos --no-fatal-warnings`
4. verify that the four `apple store` variables are non-empty (fail fast)
5. `keychain initialize`
6. `app-store-connect fetch-signing-files app.wizzo.wizzoMarket --type IOS_APP_STORE --create`
7. copy the fetched profiles into `~/Library/MobileDevice/Provisioning Profiles`
   as well (`xcodebuild -exportArchive` resolves manual-signing profiles there)
8. `keychain add-certificates`
9. `xcode-project use-profiles --archive-method app-store`
10. fail early when no `Apple Distribution` identity is in the keychain or the
    Runner Release config has no `PROVISIONING_PROFILE_SPECIFIER`
11. pick the App Store profile (exact bundle id, not expired, not a development
    profile) and write both `build/ios/ExportOptions.plist` (manual signing,
    explicit profile name, export method chosen for the installed Xcode
    version) and `build/ios/signing.env`
12. `flutter build ios --release --config-only` then `xcodebuild archive` with
    `CODE_SIGN_STYLE=Manual`, the distribution identity, team ID and profile
    specifier passed explicitly
13. verify the archived `Runner.app` is signed by an Apple Distribution
    certificate (fails here, not in the export, if it is not)
14. `xcodebuild -exportArchive -verbose` authenticated with the App Store
    Connect key
15. checks that an `.ipa` was actually produced, and prints the archived
    signature/embedded profile, before failing the build
16. uploads to TestFlight (`submit_to_testflight: true`).

The archive/export is done with `xcodebuild` directly rather than
`flutter build ipa` because Flutter **exits 0 when `-exportArchive` fails** (it
counts the archive as success). That made the old workflow reach this step with
an `.xcarchive` and no `.ipa`.

Artifacts: `build/ios/ipa/*.ipa`, `build/ios/ipa/*.pkg`,
`build/ios/archive/*.xcarchive` and `/tmp/xcodebuild_logs/*.log`.

## 4. Versioning

`pubspec.yaml` is the single source of truth:

```yaml
version: 1.4.12+43   # 1.4.12 = version name, 43 = build number
```

App Store Connect rejects a build number that was already uploaded for the same
version. For every new upload bump the number (`1.4.12+44`, `1.4.12+45`, …) and,
for a new store version, the name (`1.5.0+44`).

## 5. If the build fails again

| Log message | Fix |
|---|---|
| `argument --private-key: Missing value PRIVATE_KEY` | The API key is not reaching the step. Add `APP_STORE_CONNECT_PRIVATE_KEY` (full `.p8` text, not a file path) to the `apple store` group, or reference the integration with `integrations: app_store_connect: <name>`. The "Verify App Store Connect credentials" step lists what is missing. |
| `No valid code signing certificates were found` | The `keychain` steps are missing, or `CERTIFICATE_PRIVATE_KEY` is not set/does not match the certificate. Check the "Fetch App Store signing files" step output. |
| `No matching profiles found` | The App ID `app.wizzo.wizzoMarket` does not exist, or the API key lacks App Manager rights. Create the App ID and app record first. |
| `401 ... Authentication credentials are missing or invalid` | The Key ID and the `.p8` do not belong together (Apple names the file `AuthKey_<KEY_ID>.p8` — they must match), the key was revoked, the Issuer ID is from another team, or a value has quotes/whitespace. Check the "Inspect App Store Connect credentials" step: brackets must be tight, `p8 chars` above ~200. |
| `The provided entity includes an attribute with a value that has already been used` | The build number was already uploaded. Bump it in `pubspec.yaml`. |
| `Invalid Bundle. The bundle at ... does not support the minimum OS Version` | Deployment target must stay at 15.0 in the Xcode project and `AppFrameworkInfo.plist`. |
| `Provisioning profile ... doesn't include signing certificate` | `keychain add-certificates` did not run or imported the wrong certificate. |
| `Skip publishing to App Store Connect: no IPAs or PKGs found` | No `.ipa` reached the artifact list, so there was nothing to upload. The "Verify IPA artifact" step now prints `build/ios` and fails the build when the export produced no IPA. Also confirm the run used **this** YAML workflow: *Start new build → Wizzo Market iOS – App Store*. A build configured in the Flutter Workflow Editor ignores `codemagic.yaml` (and its `publishing` block) completely. |
| Archive exists in `build/ios/archive` but `build/ios/ipa` is missing | `flutter build ipa` reports export failures but still **exits 0** (it counts the archive as success), which is why the Build step looked green. The workflow now builds the archive with `xcodebuild` directly, using the distribution identity + App Store profile, and exports with `-verbose` so the real error is printed. Look for `error: exportArchive:` in the Export IPA step or `/tmp/xcodebuild_logs/export.log`. |
| `The archive was not signed with a distribution certificate` | The profile applied to the Runner target was a development/ad-hoc one, or `CERTIFICATE_PRIVATE_KEY` imported a certificate that is not in the App Store profile. The workflow now passes `--archive-method app-store`, filters `get-task-allow` profiles, and pins `CODE_SIGN_IDENTITY` to the distribution identity in the keychain. |
| `No provisioning profile for app.wizzo.wizzoMarket was found` in Write signing configuration | `fetch-signing-files` saves profiles to `~/Library/Developer/Xcode/UserData/Provisioning Profiles`. The workflow reads that directory and installs the profiles into `~/Library/MobileDevice/Provisioning Profiles`; both are searched. If both are empty, the fetch step failed (check the App ID and API-key rights). |
| `error: exportArchive: ... doesn't include signing certificate` | The fetched profile was issued for a different distribution certificate than the one in the keychain. Re-run with the same `CERTIFICATE_PRIVATE_KEY` used to create the profile, or delete stale distribution certificates in the Apple Developer Portal (Apple allows 3). |
| `The archive was signed with a development certificate` / export rejects a development profile | `xcode-project use-profiles` picked a non-App Store profile. The workflow now passes `--archive-method app-store`; make sure only App Store profiles are in the `apple store` signing setup. |
| `No Apple Distribution identity in the keychain` | `keychain add-certificates` did not import a distribution certificate — `CERTIFICATE_PRIVATE_KEY` is missing or does not match the certificate in the `apple store` group. |
| `PROVISIONING_PROFILE_SPECIFIER is empty` | `xcode-project use-profiles` did not find a downloaded profile for `app.wizzo.wizzoMarket`. Check the "Fetch App Store signing files" output and that the App ID exists. |
| `Missing value PRIVATE_KEY` / `401` while uploading (not skipped) | The three `APP_STORE_CONNECT_*` values reached the build but Apple rejected them — see the rows above; `publishing.app_store_connect.api_key` must contain the `.p8` **contents**, not a file path. |

## 6. After the upload

1. Wait for App Store Connect processing (10–30 min). If Apple emails an
   "Invalid Binary" warning, fix it and upload a new build number.
2. Answer Export Compliance: **No** (`ITSAppUsesNonExemptEncryption=false` is
   already in `Info.plist`).
3. Test through TestFlight, then attach the build to the store version and
   submit for review. The full listing/App Privacy/reviewer notes are in
   [`APPSTORE_RELEASE.md`](APPSTORE_RELEASE.md).
