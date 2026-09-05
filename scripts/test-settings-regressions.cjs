/* Run: NODE_PATH="$(npm root -g)" node --test scripts/test-settings-regressions.cjs
 * Requires TypeScript (test tooling only). These are mocked logic/source tests,
 * NOT an ArkTS compile, ArkUI rendering test or real-device snapshot test.
 */
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');
const ts = require('typescript');
const root = path.resolve(__dirname, '..');
const etsRoot = path.join(root, 'entry/src/main/ets');
const source = file => fs.readFileSync(path.join(etsRoot, file), 'utf8');
const tick = async () => { for (let i = 0; i < 12; i++) await Promise.resolve(); };
const ThemePreference = { SYSTEM: 'SYSTEM', LIGHT: 'LIGHT', DARK: 'DARK' };
const LanguagePreference = { SYSTEM: 'SYSTEM', ENGLISH: 'ENGLISH',
  SIMPLIFIED_CHINESE: 'SIMPLIFIED_CHINESE', TRADITIONAL_CHINESE: 'TRADITIONAL_CHINESE' };
const stage = { SHOWN: 1, RESUMED: 2, PAUSED: 3, HIDDEN: 4 };
const events = { WINDOW_SHOWN: 1, WINDOW_ACTIVE: 2, WINDOW_INACTIVE: 3, WINDOW_HIDDEN: 4 };

function environment() {
  const state = new Map();
  const preferences = new Map();
  const tags = [];
  const languages = [];
  const colors = [];
  const logs = [];
  const env = { state, preferences, tags, languages, colors, logs, os: 'zh-Hans-CN',
    failFlush: false, failLanguage: false, hide: true, localeCallback: undefined, unsubscribed: false };
  const store = {
    getSync: (k, fallback) => preferences.has(k) ? preferences.get(k) : fallback,
    putSync: (k, v) => preferences.set(k, v),
    flush: async () => { if (env.failFlush) { env.failFlush = false; throw Error('flush failure'); } }
  };
  const application = {
    setLanguage: language => { if (env.failLanguage) throw Error('native language failure'); languages.push(language); },
    setColorMode: mode => colors.push(mode)
  };
  env.context = { getApplicationContext: () => application };
  env.frames = [];
  env.ui = { runScopedTask: callback => callback(), postFrameCallback: callback => env.frames.push(callback) };
  env.render = () => { const frames = env.frames.splice(0); for (const frame of frames) frame.onIdle(2e6); };
  const kit = {
    '@kit.AbilityKit': { UIAbility: class { constructor() { this.context = env.context; } },
      ConfigurationConstant: { ColorMode: { COLOR_MODE_LIGHT: 1, COLOR_MODE_DARK: 0, COLOR_MODE_NOT_SET: -1 } } },
    '@kit.ArkData': { preferences: { getPreferencesSync: () => store } },
    '@kit.LocalizationKit': { i18n: { System: {
      getSystemLanguage: () => env.os, setAppPreferredLanguage: language => tags.push(language)
    } } },
    '@kit.ArkUI': { FrameCallback: class {}, window: { WindowStageLifecycleEventType: stage, WindowEventType: events } },
    '@kit.PerformanceAnalysisKit': { hilog: { info: (...args) => logs.push(args), error: (...args) => logs.push(args) } },
    '@kit.BasicServicesKit': { commonEventManager: {
      Support: { COMMON_EVENT_LOCALE_CHANGED: 'usual.event.LOCALE_CHANGED' },
      createSubscriberSync: info => ({ info }),
      subscribe: (subscriber, callback) => { env.localeCallback = callback; },
      unsubscribe: (subscriber, callback) => { env.unsubscribed = true; callback(undefined); }
    } }
  };
  const cache = new Map();
  env.load = file => {
    const absolute = path.resolve(etsRoot, file.endsWith('.ets') ? file : file + '.ets');
    if (cache.has(absolute)) return cache.get(absolute);
    const module = { exports: {} };
    cache.set(absolute, module.exports);
    const result = ts.transpileModule(fs.readFileSync(absolute, 'utf8'), {
      reportDiagnostics: true, compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
    });
    assert.equal((result.diagnostics || []).filter(d => d.category === ts.DiagnosticCategory.Error).length, 0);
    const requireMock = name => {
      if (kit[name]) return kit[name];
      if (name.endsWith('/models/AppModels')) return { ThemePreference, LanguagePreference };
      if (name.endsWith('SecuritySettingsManager')) return { readSecuritySettings: () => ({ hideTaskPreview: env.hide, clearClipboard: true }) };
      return env.load(path.resolve(path.dirname(absolute), name));
    };
    vm.runInNewContext(result.outputText, {
      module, exports: module.exports, require: requireMock,
      AppStorage: { setOrCreate: (k, v) => state.set(k, v) },
      console: { info: (...args) => logs.push(args), error: (...args) => logs.push(args) }
    }, { filename: absolute });
    return module.exports;
  };
  env.window = (automatic = true) => {
    const win = { private: false, focused: true, requests: [], activeRequests: 0, maxActiveRequests: 0,
      auto: automatic, failNext: false, mismatch: false, listeners: new Map(),
      isFocused: () => win.focused, getUIContext: () => env.ui,
      getWindowProperties: () => ({ isPrivacyMode: win.private }),
      on: (name, callback) => win.listeners.set(name, callback),
      off: name => win.listeners.delete(name),
      setWindowPrivacyMode: target => {
        win.activeRequests++;
        win.maxActiveRequests = Math.max(win.maxActiveRequests, win.activeRequests);
        return new Promise((resolve, reject) => {
          const request = { target,
            resolve: () => { win.activeRequests--; win.private = win.mismatch ? !target : target; resolve(); },
            reject: () => { win.activeRequests--; reject({ code: 201, message: 'permission denied' }); } };
          win.requests.push(request);
          if (win.auto) { if (win.failNext) { win.failNext = false; request.reject(); } else request.resolve(); }
        });
      }
    };
    return win;
  };
  env.security = env.load('security/ScreenSecurityManager.ets');
  env.start = async (page = 'SETTINGS') => {
    const win = env.window();
    env.security.attachScreenSecurity(env.context, win);
    env.security.setCurrentScreen(env.context, page);
    env.security.markScreenContentReady(env.context, env.ui);
    env.security.handleWindowStageLifecycle(stage.RESUMED);
    env.security.handleWindowEvent(events.WINDOW_ACTIVE);
    env.render();
    await tick();
    return win;
  };
  return env;
}

for (const [tag, expected] of [
  ['zh-Hans-CN', 'zh-Hans'], ['zh-Hant-TW', 'zh-Hant'], ['zh-HK', 'zh-Hant'],
  ['zh-Hans-HK', 'zh-Hans'], ['zh_MO', 'zh-Hant'], ['en-US', 'en'], ['ja-JP', 'en']
]) {
  test('SYSTEM language resolution: ' + tag, () => {
    const env = environment();
    const manager = env.load('localization/LanguageManager.ets');
    assert.equal(manager.resolveLanguageTag('SYSTEM', tag), expected);
  });
}

test('English -> SYSTEM applies current OS language now and keeps SYSTEM persisted', async () => {
  const env = environment(); const language = env.load('localization/LanguageManager.ets');
  await language.saveLanguagePreference(env.context, 'ENGLISH');
  language.applyLanguagePreference(env.context, 'ENGLISH');
  await language.saveLanguagePreference(env.context, 'SYSTEM');
  language.applyLanguagePreference(env.context, 'SYSTEM');
  assert.deepEqual(env.tags, ['en', 'zh-Hans']);
  assert.deepEqual(env.languages, ['en', 'zh-Hans']);
  assert.equal(language.readLanguagePreference(env.context), 'SYSTEM');
  env.os = 'zh-Hant-TW'; language.refreshSystemLanguage(env.context);
  assert.equal(env.languages.at(-1), 'zh-Hant');
  assert.equal(language.readLanguagePreference(env.context), 'SYSTEM');
  const count = env.tags.length; language.refreshSystemLanguage(env.context);
  assert.equal(env.tags.length, count); // No configuration update loop.
});

test('explicit language is not overwritten when OS language changes', async () => {
  const env = environment(); const language = env.load('localization/LanguageManager.ets');
  await language.saveLanguagePreference(env.context, 'ENGLISH');
  language.applyLanguagePreference(env.context, 'ENGLISH');
  env.os = 'zh-Hant-TW'; language.refreshSystemLanguage(env.context);
  assert.deepEqual(env.languages, ['en']);
});

test('failed persistence restores preference cache instead of rereading the failed new value', async () => {
  const env = environment();
  for (const [file, save, read, initial, replacement] of [
    ['localization/LanguageManager.ets', 'saveLanguagePreference', 'readLanguagePreference', 'ENGLISH', 'SYSTEM'],
    ['design/ThemeManager.ets', 'saveThemePreference', 'readThemePreference', 'DARK', 'LIGHT']
  ]) {
    const manager = env.load(file); assert.equal(await manager[save](env.context, initial), true);
    env.failFlush = true; assert.equal(await manager[save](env.context, replacement), false);
    assert.equal(manager[read](env.context), initial);
  }
});

test('native language failures are returned, not reported as success', () => {
  const env = environment(); env.failLanguage = true;
  assert.equal(env.load('localization/LanguageManager.ets').applyLanguagePreference(env.context, 'ENGLISH'), false);
});

test('theme uses LIGHT, DARK and NOT_SET rather than a resolved theme snapshot', () => {
  const env = environment(); const theme = env.load('design/ThemeManager.ets');
  for (const preference of ['LIGHT', 'DARK', 'SYSTEM']) assert.equal(theme.applyThemePreference(env.context, preference), true);
  assert.deepEqual(env.colors, [1, 0, -1]);
});

for (const page of ['ONBOARDING', 'SETTINGS', 'ABOUT', 'UNLOCK', 'AUTHENTICATOR', 'VAULT', 'GENERATOR', 'UNKNOWN']) {
  test('foreground capture policy: ' + page, async () => {
    const env = environment(); const win = await env.start(page);
    assert.equal(win.private, !['ONBOARDING', 'SETTINGS', 'ABOUT'].includes(page));
    assert.equal(env.state.get('timeauth.screenCovered'), false);
    assert.equal(win.maxActiveRequests, 1);
  });
}

test('focus loss covers actual UI immediately, before privacy Promise resolves', async () => {
  const env = environment(); const win = await env.start(); win.auto = false;
  env.security.handleWindowEvent(events.WINDOW_INACTIVE);
  assert.equal(env.state.get('timeauth.screenCovered'), true);
  assert.equal(win.requests.at(-1).target, true);
  assert.equal(win.private, false);
  win.requests.at(-1).resolve(); await tick(); assert.equal(win.private, true);
});

test('foreground alone or SHOWN cannot uncover a paused window', async () => {
  const env = environment(); await env.start();
  env.security.handleWindowStageLifecycle(stage.PAUSED);
  env.security.handleWindowEvent(events.WINDOW_INACTIVE);
  env.security.setScreenAbilityForeground(false); await tick();
  env.security.setScreenAbilityForeground(true);
  env.security.handleWindowStageLifecycle(stage.SHOWN);
  env.security.handleWindowEvent(events.WINDOW_ACTIVE); await tick();
  assert.equal(env.state.get('timeauth.screenCovered'), true);
  env.security.handleWindowStageLifecycle(stage.RESUMED); await tick();
  assert.equal(env.state.get('timeauth.screenCovered'), false);
});

test('old foreground privacy=false cannot win a later background privacy=true request', async () => {
  const env = environment(); const win = await env.start('AUTHENTICATOR'); win.auto = false;
  env.security.setCurrentScreen(env.context, 'SETTINGS'); env.render();
  const request = win.requests.at(-1); assert.equal(request.target, false);
  env.security.handleWindowEvent(events.WINDOW_INACTIVE);
  assert.equal(env.state.get('timeauth.screenCovered'), true);
  request.resolve(); await tick();
  assert.equal(win.requests.at(-1).target, true);
  win.requests.at(-1).resolve(); await tick();
  assert.equal(win.private, true); assert.equal(win.maxActiveRequests, 1);
  assert.equal(env.state.get('timeauth.screenCovered'), true);
});

test('safe-page transition remains protected until its replacement frame is rendered', async () => {
  const env = environment(); const win = await env.start('AUTHENTICATOR');
  env.security.setCurrentScreen(env.context, 'SETTINGS'); await tick();
  assert.equal(win.private, true); assert.equal(env.state.get('timeauth.screenCovered'), true);
  env.render(); await tick(); assert.equal(win.private, false);
});

test('disabling recents hiding never disables sensitive-page capture protection', async () => {
  const env = environment(); const win = await env.start('VAULT');
  env.hide = false; env.security.refreshScreenSecurity(env.context);
  env.security.handleWindowEvent(events.WINDOW_INACTIVE); await tick();
  assert.equal(win.private, true); assert.equal(env.state.get('timeauth.screenCovered'), true);
});

test('safe screen can opt out of recents cover without affecting other pages', async () => {
  const env = environment(); const win = await env.start();
  env.hide = false; env.security.refreshScreenSecurity(env.context);
  env.security.handleWindowEvent(events.WINDOW_INACTIVE); await tick();
  assert.equal(win.private, false); assert.equal(env.state.get('timeauth.screenCovered'), false);
});

test('privacy rejection leaves protected content covered and exposes an error', async () => {
  const env = environment(); const win = await env.start(); win.failNext = true;
  env.security.setCurrentScreen(env.context, 'VAULT'); env.render(); await tick();
  assert.equal(env.state.get('timeauth.screenProtectionFailed'), true);
  assert.equal(env.state.get('timeauth.screenCovered'), true);
  env.security.refreshScreenSecurity(env.context); env.render(); await tick();
  assert.equal(env.state.get('timeauth.screenProtectionFailed'), false);
  assert.equal(win.private, true); assert.equal(env.state.get('timeauth.screenCovered'), false);
});

test('native acknowledgement mismatch is not accepted as protection', async () => {
  const env = environment(); const win = await env.start(); win.mismatch = true;
  env.security.setCurrentScreen(env.context, 'VAULT'); env.render(); await tick();
  assert.equal(env.state.get('timeauth.screenProtectionFailed'), true);
  assert.equal(env.state.get('timeauth.screenCovered'), true);
});

test('destroyed-window callbacks cannot alter the new window state', async () => {
  const env = environment(); const old = await env.start(); old.auto = false;
  env.security.handleWindowEvent(events.WINDOW_INACTIVE);
  const pending = old.requests.at(-1); env.security.detachScreenSecurity();
  const current = await env.start(); pending.reject(); await tick();
  assert.equal(env.state.get('timeauth.screenProtectionFailed'), false);
  assert.equal(env.state.get('timeauth.screenCovered'), false);
  assert.equal(current.private, false);
});

test('setup failure is sticky until a new window is attached', async () => {
  const env = environment(); const win = await env.start();
  env.security.reportScreenSecuritySetupFailure(); await tick();
  assert.equal(env.state.get('timeauth.screenProtectionFailed'), true);
  assert.equal(env.state.get('timeauth.screenCovered'), true); assert.equal(win.private, true);
});

test('ability applies settings only after loadContent and subscribes/unsubscribes OS locale events', async () => {
  const env = environment(); const Entry = env.load('entryability/EntryAbility.ets').default;
  const entry = new Entry(); const win = env.window(); let loaded;
  const stageInstance = { getMainWindowSync: () => win, on() {}, off() {}, loadContent: (name, cb) => { loaded = cb; } };
  entry.onCreate({}, {}); entry.onWindowStageCreate(stageInstance);
  assert.equal(env.tags.length, 0); assert.equal(env.colors.length, 0);
  loaded({ code: 0 }); assert.equal(env.languages.at(-1), 'zh-Hans');
  env.os = 'zh-Hant-TW'; env.localeCallback(undefined, { event: 'usual.event.LOCALE_CHANGED' });
  assert.equal(env.languages.at(-1), 'zh-Hant');
  env.os = 'en-US'; entry.onForeground(); assert.equal(env.languages.at(-1), 'en');
  entry.onWindowStageDestroy(); entry.onDestroy(); assert.equal(env.unsubscribed, true);
  assert.equal(win.listeners.size, 0); await tick();
});

test('source regression: reactive values are read inside Text/Toggle, not by-value builder arguments', () => {
  const settings = source('features/settings/SettingsPage.ets');
  assert.match(settings, /PreferenceSelectionRow\(isAppearance: boolean\)/);
  assert.match(settings, /Text\(isAppearance \? this\.themeLabel\(this\.themePreference\) : this\.languageLabel\(this\.languagePreference\)\)/);
  assert.match(settings, /isOn: isTaskPreview \? this\.hideTaskPreview : this\.clearClipboard/);
  assert.doesNotMatch(settings, /themeDialogIndex|languageDialogIndex|PreferenceSelectionRow\(title:/);
  assert.match(settings, /onScreenCoverChanged/); assert.match(settings, /closePreferenceDialogs/);
});

test('source regression: opaque root cover, correct public window event, no old focus listener', () => {
  assert.match(source('pages/Index.ets'), /Visibility\.Hidden/);
  assert.match(source('pages/Index.ets'), /no-hide-descendants/);
  assert.match(source('pages/Index.ets'), /id\('privacy-cover'\)/);
  const entry = source('entryability/EntryAbility.ets');
  assert.match(entry, /mainWindow\.on\('windowEvent'/);
  assert.match(entry, /on\('windowStageLifecycleEvent'/);
  assert.doesNotMatch(entry, /on\('windowStageEvent'/);
  assert.doesNotMatch(source('security/ScreenSecurityManager.ets'), /setSnapshotSkip|abilityContext\.windowStage/);
});

test('new feedback resources have matching locale keys and no local duplicates', () => {
  const sets = ['base', 'zh_Hans', 'zh_Hant'].map(locale => {
    const dir = path.join(root, 'entry/src/main/resources', locale, 'element');
    const seen = new Set();
    for (const file of fs.readdirSync(dir).filter(file => file.endsWith('.json'))) {
      const data = JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8'));
      for (const [type, values] of Object.entries(data)) {
        for (const value of values) {
          const key = type + ':' + value.name; assert.ok(!seen.has(key), `duplicate ${locale}/${key}`); seen.add(key);
        }
      }
    }
    const data = JSON.parse(fs.readFileSync(path.join(dir, 'runtime_feedback.json'), 'utf8'));
    return data.string.map(item => item.name).sort();
  });
  assert.deepEqual(sets[0], sets[1]); assert.deepEqual(sets[0], sets[2]);
});
