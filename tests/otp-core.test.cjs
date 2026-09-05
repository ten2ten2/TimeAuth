'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { load, draft } = require('./otp-test-support.cjs');
const a = load();

const vectors = [
  [59, '94287082', '46119246', '90693936'],
  [1111111109, '07081804', '68084774', '25091201'],
  [1111111111, '14050471', '67062674', '99943326'],
  [1234567890, '89005924', '91819424', '93441116'],
  [2000000000, '69279037', '90698825', '38618901'],
  [20000000000, '65353130', '77737706', '47863826']
];
for (const [algorithm, length, column] of [['SHA1',20,1],['SHA256',32,2],['SHA512',64,3]]) {
  for (const vector of vectors) {
    test(`RFC 6238 ${algorithm}, unix=${vector[0]}`, async () => {
      const secret = a.encodeBase32(Buffer.from('1234567890'.repeat(7).slice(0,length)));
      assert.equal(await new a.NativeOtpCrypto().generate(draft(a, { secret, algorithm, digits: 8 }),
        a.otpCounter(vector[0] * 1000, 30)), vector[column]);
    });
  }
}
const hotp = ['755224','287082','359152','969429','338314','254676','287922','162583','399871','520489'];
for (let counter = 0; counter < hotp.length; counter++) {
  test(`RFC 4226 dynamic truncation vector ${counter}`, async () => {
    assert.equal(await new a.NativeOtpCrypto().generate(draft(a), counter), hotp[counter]);
  });
}
for (const [text, encoded] of [['f','MY======'],['fo','MZXQ===='],['foo','MZXW6==='],
  ['foob','MZXW6YQ='],['fooba','MZXW6YTB'],['foobar','MZXW6YTBOI======']]) {
  test(`RFC 4648 Base32 ${text}`, () => {
    assert.equal(Buffer.from(a.decodeBase32(encoded)).toString(), text);
    assert.equal(a.encodeBase32(Buffer.from(text)), encoded.replace(/=+$/,''));
  });
}
test('Base32 handles grouping/case and rejects malformed padding, alphabet and unused bits', () => {
  assert.equal(Buffer.from(a.decodeBase32('mzxw-6ytb\noi======')).toString(), 'foobar');
  for (const invalid of ['', 'A', 'ABC', 'ABCDEF', '0AAAAAAA', '1AAAAAAA', 'MZ', 'MY=', 'MY======A',
    'MY==============', 'MZXW6YTB=', 'M=Y=====', 'a'.repeat(2049)]) {
    assert.throws(() => a.decodeBase32(invalid), { code: a.OtpErrorCode.INVALID_SECRET }, invalid);
  }
});
test('Base32 round trips random keys without silently altering bytes', () => {
  for (let n = 1; n <= 512; n += 7) {
    const bytes = crypto.randomBytes(n);
    assert.deepEqual(Buffer.from(a.decodeBase32(a.encodeBase32(bytes))), bytes);
  }
});
test('native adapter clears imported key material after HMAC', async () => {
  const isolated = load();
  await new isolated.NativeOtpCrypto().generate(draft(isolated), 0);
  assert.equal(isolated.stats.imported, 1); assert.equal(isolated.stats.cleared, 1);
});
test('variable-length HMAC seeds work for all three algorithms', async () => {
  for (const algorithm of ['SHA1','SHA256','SHA512']) {
    const seed = crypto.randomBytes(37);
    const expected = crypto.createHmac(algorithm.toLowerCase(), seed).update(Buffer.from(a.counterBytes(3))).digest();
    const code = await new a.NativeOtpCrypto().generate(draft(a, { secret:a.encodeBase32(seed), algorithm }), 3);
    assert.equal(code, a.truncateOtp(expected, a.OtpKind.TOTP, 6));
  }
});
test('Steam shared_secret Base64 is explicitly decoded to the same 20 bytes', () => {
  const seed = Buffer.from('12345678901234567890');
  assert.equal(a.steamSharedSecretToBase32(seed.toString('base64')), a.encodeBase32(seed));
  for (const invalid of ['abc', seed.toString('base64').slice(0,-1), Buffer.alloc(21).toString('base64'),
    seed.toString('base64').slice(0,26)+'B=']) {
    assert.throws(() => a.steamSharedSecretToBase32(invalid));
  }
});
test('Steam uses least-significant-base26 first, not a decimal 5-digit OTP', async () => {
  const account = draft(a, { kind: a.OtpKind.STEAM, digits: 5 });
  const hmac = crypto.createHmac('sha1', Buffer.from(a.decodeBase32(account.secret)))
    .update(Buffer.from(a.counterBytes(123456))).digest();
  let value = hmac.readUInt32BE(hmac[hmac.length-1] & 15) & 0x7fffffff;
  let expected = '';
  for (let i=0;i<5;i++) { expected += '23456789BCDFGHJKMNPQRTVWXY'[value % 26]; value=Math.floor(value/26); }
  assert.equal(await new a.NativeOtpCrypto().generate(account, 123456), expected);
});
test('counter uses 64-bit big endian and is safe beyond 2038/32-bit boundaries', () => {
  assert.equal(Buffer.from(a.counterBytes(0x100000001)).toString('hex'), '0000000100000001');
  assert.equal(a.otpCounter(20000000000000,30),666666666);
  assert.throws(() => a.counterBytes(Number.MAX_SAFE_INTEGER + 1));
  assert.throws(() => a.otpCounter(-1,30));
});
test('countdown derives from absolute time including exact boundaries and non-30-second periods', () => {
  for (const period of [1,30,45,60,86400]) {
    assert.equal(a.remainingSeconds(period*1000,period),period);
    assert.equal(a.remainingSeconds(period*1000-1,period),1);
  }
  assert.equal(a.otpCounter(30000,30),1);
});
test('display grouping preserves leading zeros, Steam letters and 8-digit lengths', () => {
  assert.equal(a.displayOtp('001234'),'001 234');
  assert.equal(a.displayOtp('00123456'),'0012 3456');
  assert.equal(a.displayOtp('R9K4Q'),'R9K4Q');
});
test('draft validation enforces real parameters and rejects short or noncanonical seeds', () => {
  for (const overrides of [{digits:7},{period:0},{period:1.5},{period:86401},{algorithm:'MD5'},
    {secret:'MY======'},{issuer:' '},{issuer:'X'.repeat(129)},{account:'X'.repeat(257)},
    {issuer:'name\u202Eabc'},{kind:'HOTP'},{kind:'STEAM',digits:6}]) {
    assert.throws(() => a.validateDraft(draft(a, overrides)));
  }
  assert.equal(a.validateDraft(draft(a, {issuer:' Example ',account:' '})).issuer,'Example');
});
const uri = 'otpauth://totp/Example:demo%40example.com?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&issuer=Example';
test('URI parses UTF-8 labels and preserves all explicitly provisioned parameters', () => {
  const result = a.parseOtpAuthUri('otpauth://totp/%E9%98%BF%E9%87%8C%E4%BA%91%3Auser%2Btest%40example.com'+
    '?issuer=%E9%98%BF%E9%87%8C%E4%BA%91&secret='+draft(a).secret+'&algorithm=SHA512&digits=8&period=60');
  assert.equal(result.issuer,'阿里云'); assert.equal(result.account,'user+test@example.com');
  assert.equal(result.algorithm,'SHA512'); assert.equal(result.digits,8); assert.equal(result.period,60);
});
test('URI defaults and labels with no issuer work without guessing from account email domains', () => {
  const result = a.parseOtpAuthUri('otpauth://totp/user%40example.com?secret='+draft(a).secret);
  assert.equal(result.issuer,'user@example.com'); assert.equal(result.algorithm,'SHA1');
  assert.equal(result.digits,6); assert.equal(result.period,30);
});
test('URI issuer conflicts, repeated params, malformed percentages, unsupported schemes and imports fail explicitly', () => {
  const cases = [uri+'&issuer=Other', uri+'&secret='+draft(a).secret, uri.replace('issuer=Example','issuer=Other'),
    uri+'&period=30junk',uri+'&digits=7',uri+'&algorithm=MD5',uri+'&encoder=unknown',uri+'&counter=1',
    uri.replace('totp/','hotp/'),uri.replace('Example:','%ZZ:'),'https://example.com/'+uri,
    'otpauth-migration://offline?data=abc',uri+'#secret=else',uri.replace(/secret=[^&]+/,'secret=')];
  for (const value of cases) assert.throws(() => a.parseOtpAuthUri(value), undefined, value.slice(0,45));
});
test('URI supports explicit Steam encoder without inferring a special algorithm from a logo/name', () => {
  const encoded = a.parseOtpAuthUri(uri.replaceAll('Example','Steam')+'&encoder=steam');
  assert.equal(encoded.kind,'STEAM'); assert.equal(encoded.digits,5); assert.equal(encoded.period,30);
  assert.equal(a.parseOtpAuthUri(uri.replaceAll('Example','Steam')).kind,'TOTP');
});
test('all thrown validation errors exclude secret material and account identifiers', () => {
  try { a.parseOtpAuthUri(uri+'&period=garbage'); } catch(error) {
    assert.doesNotMatch(error.message,/GEZD|demo|example|garbage/);
  }
});
