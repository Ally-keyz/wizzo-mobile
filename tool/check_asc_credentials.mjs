#!/usr/bin/env node
// Validates App Store Connect API credentials locally, before a Codemagic run.
//
// Usage:
//   node tool/check_asc_credentials.mjs <path-to-AuthKey_XXXX.p8> <KEY_ID> <ISSUER_ID>
//
// It prints the JWT header/claims it signs and Apple's HTTP status + error
// message. It never prints the private key. Exit code 0 means Apple accepted
// the token (HTTP 200), 1 means the credentials were rejected.
//
// Requires Node 18+ (global fetch), no npm packages.

import { readFileSync } from 'node:fs';
import { createPrivateKey, createSign } from 'node:crypto';

const [keyPath, keyIdArg, issuerArg] = process.argv.slice(2);

if (!keyPath || !keyIdArg || !issuerArg) {
  console.error(
    'Usage: node tool/check_asc_credentials.mjs <AuthKey_XXXX.p8> <KEY_ID> <ISSUER_ID>',
  );
  process.exit(2);
}

const keyId = keyIdArg.trim();
const issuer = issuerArg.trim();
const pem = readFileSync(keyPath, 'utf8');

if (keyId.length !== 10) {
  console.warn(`warning: Key ID is ${keyId.length} chars, Apple's are 10`);
}
if (keyId !== keyIdArg || issuer !== issuerArg) {
  console.warn('warning: Key ID or Issuer ID had surrounding whitespace');
}

try {
  const key = createPrivateKey(pem);
  if (key.asymmetricKeyType !== 'ec') {
    console.error(
      `error: this is an ${key.asymmetricKeyType.toUpperCase()} key; the App Store Connect key must be an EC (P-256) .p8`,
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
const header = { alg: 'ES256', kid: keyId, typ: 'JWT' };
const payload = {
  iss: issuer,
  iat: now,
  exp: now + 600,
  aud: 'appstoreconnect-v1',
};

const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
const signer = createSign('SHA256');
signer.update(signingInput);
signer.end();
const signature = signer.sign({ key: pem, dsaEncoding: 'ieee-p1363' });
const token = `${signingInput}.${base64url(signature)}`;

const url = new URL('https://api.appstoreconnect.apple.com/v1/bundleIds');
url.searchParams.set('limit', '1');
url.searchParams.set('filter[identifier]', 'app.wizzo.wizzoMarket');
url.searchParams.set('filter[platform]', 'IOS');

console.log(`key file:  ${keyPath}`);
console.log(`key bytes: ${Buffer.byteLength(pem)}`);
console.log(`kid:       ${keyId}`);
console.log(`iss:       ${issuer}`);
console.log('');

let response;
try {
  response = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
} catch (error) {
  console.error(`network error: ${error.message}`);
  process.exit(1);
}

const body = await response.text();
console.log(`HTTP ${response.status}`);
if (body) console.log(body.slice(0, 1200));

if (response.ok) {
  console.log('\nOK: Apple accepted the token.');
  process.exit(0);
}

if (response.status === 401) {
  console.error(
    '\nREJECTED: the Key ID, .p8 and Issuer ID do not belong together, the key was revoked, or the API key is not a Team Key. The .p8 file is named AuthKey_<KEY_ID>.p8 -- those two must match.',
  );
} else if (response.status === 403) {
  console.error(
    '\nFORBIDDEN: the token is valid but this key lacks App Manager/Admin access.',
  );
}
process.exit(1);
