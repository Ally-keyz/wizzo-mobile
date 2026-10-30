#!/usr/bin/env node
// Checks the TestFlight "Test Information" that Apple requires before a build
// can be submitted to *external* beta review.
//
// Codemagic's `submit_to_testflight: true` runs after the upload, so a missing
// Test Information page is only reported at the very end of the pipeline:
//
//   Failure: Complete test information is required to submit application
//   Wizzo Marketplace build for external testing.
//   App is missing required Beta App Information: Feedback Email.
//   App is missing required Beta App Review Information: First Name, Last
//   Name, Phone Number, Email.
//
// Those values are app level (not per build), so this script fails the build
// before the archive instead of after the ~20 min upload.
//
// Usage:
//   node tool/check_testflight_info.mjs [bundle-id]
//
// Credentials are read from the same variables the workflow uses:
//   APP_STORE_CONNECT_PRIVATE_KEY      PEM text, or a path to AuthKey_XXXX.p8
//   APP_STORE_CONNECT_KEY_IDENTIFIER
//   APP_STORE_CONNECT_ISSUER_ID
//
// Exit codes: 0 = complete (or could not be checked), 1 = fields missing.
// Requires Node 18+ (global fetch), no npm packages.

import { createPrivateKey, createSign } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';

const bundleId =
  process.argv[2] || process.env.BUNDLE_ID || 'app.wizzo.wizzoMarket';
const keyId = (process.env.APP_STORE_CONNECT_KEY_IDENTIFIER || '').trim();
const issuer = (process.env.APP_STORE_CONNECT_ISSUER_ID || '').trim();
const privateKeyValue = (process.env.APP_STORE_CONNECT_PRIVATE_KEY || '').trim();

if (!keyId || !issuer || !privateKeyValue) {
  console.log(
    'Skipping the TestFlight test information check: APP_STORE_CONNECT_PRIVATE_KEY, ' +
      'APP_STORE_CONNECT_KEY_IDENTIFIER and APP_STORE_CONNECT_ISSUER_ID must all be set.',
  );
  process.exit(0);
}

let pem = privateKeyValue;
if (!pem.includes('BEGIN PRIVATE KEY')) {
  // Codemagic normally injects the PEM text, but a path is accepted locally.
  if (!existsSync(privateKeyValue)) {
    console.error(
      `error: APP_STORE_CONNECT_PRIVATE_KEY is neither PEM text nor an existing file (${privateKeyValue}).`,
    );
    process.exit(1);
  }
  pem = readFileSync(privateKeyValue, 'utf8');
}

try {
  const key = createPrivateKey(pem);
  if (key.asymmetricKeyType !== 'ec') {
    console.error(
      `error: the App Store Connect key must be an EC (P-256) .p8, got ${key.asymmetricKeyType.toUpperCase()}.`,
    );
    process.exit(1);
  }
} catch (error) {
  console.error(`error: could not parse the private key: ${error.message}`);
  process.exit(1);
}

const base64url = (input) =>
  Buffer.from(input)
    .toString('base64')
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replace(/=+$/, '');

const now = Math.floor(Date.now() / 1000);
const signingInput = `${base64url(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }))}.${base64url(
  JSON.stringify({
    iss: issuer,
    iat: now,
    exp: now + 600,
    aud: 'appstoreconnect-v1',
  }),
)}`;
const signer = createSign('SHA256');
signer.update(signingInput);
signer.end();
const token = `${signingInput}.${base64url(
  signer.sign({ key: pem, dsaEncoding: 'ieee-p1363' }),
)}`;

async function api(path) {
  const response = await fetch(`https://api.appstoreconnect.apple.com${path}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`GET ${path} -> HTTP ${response.status} ${text.slice(0, 300)}`);
  }
  return text ? JSON.parse(text) : null;
}

let app;
try {
  const apps = await api(
    `/v1/apps?filter[bundleId]=${encodeURIComponent(bundleId)}&limit=1`,
  );
  app = apps?.data?.[0];
} catch (error) {
  console.log(`Skipping the TestFlight test information check: ${error.message}`);
  process.exit(0);
}

if (!app) {
  console.error(
    `No App Store Connect app record uses the bundle id ${bundleId} (case sensitive).`,
  );
  process.exit(1);
}

const [reviewResult, localizationResult] = await Promise.allSettled([
  api(`/v1/apps/${app.id}/betaAppReviewDetail`),
  api(`/v1/apps/${app.id}/betaAppLocalizations?limit=200`),
]);

const missing = [];

// Beta App Information -> Feedback Email (per localization; primary first).
let feedbackEmail = '';
if (localizationResult.status === 'fulfilled') {
  const localizations = localizationResult.value?.data ?? [];
  const primaryLocale = app.attributes?.primaryLocale;
  const localization =
    localizations.find((item) => item.attributes?.locale === primaryLocale) ??
    localizations[0];
  feedbackEmail = (localization?.attributes?.feedbackEmail || '').trim();
  if (!feedbackEmail) {
    missing.push('Beta App Information -> Feedback Email');
  }
} else {
  console.log(
    `warning: could not read beta app localizations, skipping that part: ${localizationResult.reason.message}`,
  );
}

// Beta App Review Information -> contact person.
if (reviewResult.status === 'fulfilled') {
  const attributes = reviewResult.value?.data?.attributes ?? {};
  const contact = {
    'First Name': attributes.contactFirstName,
    'Last Name': attributes.contactLastName,
    'Phone Number': attributes.contactPhone,
    Email: attributes.contactEmail,
  };
  for (const [label, value] of Object.entries(contact)) {
    if (!String(value || '').trim()) {
      missing.push(`Beta App Review Information -> ${label}`);
    }
  }
} else {
  console.log(
    `warning: could not read the beta app review detail, skipping that part: ${reviewResult.reason.message}`,
  );
}

const testInfoUrl = `https://appstoreconnect.apple.com/apps/${app.id}/testflight/test-info`;

if (missing.length === 0) {
  console.log(`TestFlight test information is complete for ${bundleId}.`);
  if (feedbackEmail) console.log(`Feedback email: ${feedbackEmail}`);
  process.exit(0);
}

console.error('');
console.error(
  `TestFlight test information is incomplete for ${bundleId} (${app.attributes?.name || 'app'}).`,
);
console.error('Apple rejects external beta review until these are filled in:');
for (const field of missing) console.error(`  - ${field}`);
console.error('');
console.error(`Fill them once at: ${testInfoUrl}`);
console.error(
  '  TestFlight -> Test Information -> Beta App Information / Beta App Review Information',
);
console.error(
  '  Use a monitored mailbox for the feedback email and a real person who can',
);
console.error(
  '  answer Apple for the contact fields (phone number with country code).',
);
console.error('');
console.error(
  'The values are app level, so they apply to every later build. Demo account and',
);
console.error(
  'reviewer notes: APPSTORE_RELEASE.md section 7. No rebuild is needed to submit',
);
console.error(
  'an already-uploaded build; or set submit_to_testflight: false if you only use',
);
console.error('internal testers.');
process.exit(1);
