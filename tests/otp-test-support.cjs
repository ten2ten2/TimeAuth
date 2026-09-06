'use strict';
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const corePath = 'entry/src/main/ets/features/authenticator/';
function load(extra = {}) {
  const stats = { imported: 0, cleared: 0, hmac: 0 };
  const cryptoFramework = {
    createRandom: () => ({ generateRandomSync: length => ({ data: new Uint8Array(crypto.randomBytes(length)) }) }),
    createSymKeyGenerator: algorithm => {
      if (algorithm !== 'HMAC') throw new Error('HMAC must accept variable-length seeds');
      return { convertKey: async ({ data }) => {
        stats.imported++;
        return { data: Buffer.from(data), clearMem() { this.data.fill(0); stats.cleared++; } };
      }};
    },
    createMac: algorithm => {
      let mac;
      return {
        init: async key => { mac = crypto.createHmac(algorithm.toLowerCase(), key.data); },
        update: async ({ data }) => { mac.update(data); },
        doFinal: async () => { stats.hmac++; return { data: new Uint8Array(mac.digest()) }; }
      };
    }
  };
  const storage = new Map();
  const sandbox = {
    cryptoFramework, Uint8Array, Map, setTimeout, clearTimeout,
    relationalStore: { SecurityLevel: { S3: 3 } },
    AppStorage: { setOrCreate: (key, value) => storage.set(key, value) }, ...extra
  };
  const files = ['entry/src/main/ets/models/AppModels.ets', corePath + 'OtpCore.ets', corePath + 'OtpCrypto.ets',
    'entry/src/main/ets/security/AppSession.ets', corePath + 'OtpRepository.ets', corePath + 'OtpSession.ets',
    corePath + 'OtpViewItem.ets'];
  const code = files.map(file => read(file).replace(/^import[\s\S]*?;\r?\n/gm, '')
    .replace(/^@Observed\s*$/gm, '').replace(/\bexport /g, '')).join('\n');
  const names = ['OtpKind','OtpAlgorithm','OtpError','OtpErrorCode','decodeBase32','encodeBase32',
    'steamSharedSecretToBase32','validateDraft','parseOtpAuthUri','accountFromDraft','credentialIdentity',
    'otpCounter','counterBytes','remainingSeconds','truncateOtp','displayOtp','emptyOtpDraft','NativeOtpCrypto',
    'newOtpId','OtpSession','OtpViewItem','EncryptedOtpRepository','lockAppSession','unlockAppSession',
    'isAppSessionUnlocked','setAppSessionForeground','appSessionEpoch'];
  vm.runInNewContext(stripTypeScriptTypes(code + `\nglobalThis.api = {${names.join(',')}}`, { mode: 'transform' }), sandbox);
  return Object.assign(sandbox.api, { stats, storage });
}
function draft(api, overrides = {}) {
  return { issuer: 'Example', account: 'demo@example.com',
    secret: api.encodeBase32(Buffer.from('12345678901234567890')),
    kind: api.OtpKind.TOTP, algorithm: api.OtpAlgorithm.SHA1, digits: 6, period: 30, counter: 0, ...overrides };
}
const clone = value => JSON.parse(JSON.stringify(value));
const deferred = () => { let resolve, reject; const promise = new Promise((a,b) => { resolve=a; reject=b; }); return {promise,resolve,reject}; };
module.exports = { load, draft, clone, deferred, root, read, corePath };
