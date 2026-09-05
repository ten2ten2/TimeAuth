const assert = require('node:assert/strict');
const { before, beforeEach, test } = require('node:test');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const key = 'timeauth.onboarding.completed.v1';
let api, cache, disk, failure, waitForFlush;
function url(source) {
  return `data:text/javascript;base64,${Buffer.from(stripTypeScriptTypes(source, { mode: 'transform' })).toString('base64')}`;
}
before(async () => {
  globalThis.__onboardingPreferences = {
    getPreferencesSync(_context, options) {
      assert.equal(options.name, 'timeauth_preferences');
      if (failure === 'open') throw new Error('private provider details');
      return {
        getSync(name, fallback) {
          if (failure === 'read') throw new Error('private provider details');
          return cache.has(name) ? cache.get(name) : fallback;
        },
        putSync(name, value) {
          if (failure === 'write') throw new Error('private provider details');
          cache.set(name, value);
        },
        async flush() {
          if (failure === 'flush') throw new Error('private provider details');
          if (waitForFlush) await waitForFlush;
          disk = new Map(cache);
        }
      };
    }
  };
  const source = readFileSync(join(__dirname,
    '../entry/src/main/ets/features/onboarding/OnboardingSettings.ets'), 'utf8')
    .replace("'@kit.AbilityKit'", JSON.stringify(url('export const common = {};')))
    .replace("'@kit.ArkData'", JSON.stringify(url('export const preferences = globalThis.__onboardingPreferences;')));
  api = await import(url(source));
  delete globalThis.__onboardingPreferences;
});
beforeEach(() => {
  cache = new Map(); disk = new Map(); failure = ''; waitForFlush = undefined;
});
test('first launch and malformed flags do not skip onboarding', () => {
  assert.equal(api.isOnboardingCompleted({}), false);
  for (const value of [false, 'true', 1, null]) {
    cache.set(key, value);
    assert.equal(api.isOnboardingCompleted({}), false);
  }
});
test('completion survives process restart and preserves other preferences', async () => {
  cache.set('timeauth.generator.options.v1', 'existing settings');
  assert.equal(await api.completeOnboarding({}), true);
  cache = new Map(disk);
  assert.equal(api.isOnboardingCompleted({}), true);
  assert.equal(cache.get('timeauth.generator.options.v1'), 'existing settings');
});
test('storage errors do not mark onboarding complete and a retry recovers', async () => {
  for (const mode of ['open', 'read', 'write', 'flush']) {
    failure = mode;
    assert.equal(await api.completeOnboarding({}), false);
    assert.equal(disk.get(key), undefined);
    failure = '';
    assert.equal(api.isOnboardingCompleted({}), false);
  }
  assert.equal(await api.completeOnboarding({}), true);
});
test('completion waits for durable storage before allowing navigation', async () => {
  let release;
  waitForFlush = new Promise(resolve => { release = resolve; });
  let done = false;
  const saving = api.completeOnboarding({}).then(result => { done = true; return result; });
  await Promise.resolve();
  assert.equal(done, false);
  release();
  assert.equal(await saving, true);
});
test('clearing app data restores first-launch behavior', async () => {
  await api.completeOnboarding({});
  disk.clear(); cache = new Map(disk);
  assert.equal(api.isOnboardingCompleted({}), false);
});
