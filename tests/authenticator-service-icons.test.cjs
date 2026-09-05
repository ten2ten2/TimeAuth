'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const registry = read('entry/src/main/ets/features/authenticator/ServiceIconRegistry.ets');
const card = read('entry/src/main/ets/components/OtpCard.ets');
const page = read('entry/src/main/ets/features/authenticator/AuthenticatorPage.ets');
const mock = read('entry/src/main/ets/data/MockRepository.ets');
const media = path.join(root, 'entry/src/main/resources/base/media');

const serviceResources = [
  'service_alibaba_cloud', 'service_tencent_cloud', 'service_huawei_cloud', 'service_baidu_ai_cloud',
  'service_volcano_engine', 'service_google', 'service_microsoft', 'service_github', 'service_apple',
  'service_aws', 'service_cloudflare', 'service_steam', 'service_discord', 'service_dropbox', 'service_slack',
  'service_bitwarden', 'service_1password', 'service_gitlab', 'service_proton', 'service_openai'
];
const issuers = [
  '阿里云', '腾讯云', '华为云', '百度智能云', '火山引擎', 'Google', 'Microsoft', 'GitHub', 'Apple', 'AWS',
  'Cloudflare', 'Steam', 'Discord', 'Dropbox', 'Slack', 'Bitwarden', '1Password', 'GitLab', 'Proton', 'OpenAI'
];

test('first service-icon batch contains exactly 20 local SVG resources', () => {
  assert.equal(serviceResources.length, 20);
  for (const name of serviceResources) {
    const svg = read(`entry/src/main/resources/base/media/${name}.svg`);
    assert.match(svg, /<svg\b/);
    assert.match(svg, /viewBox="0 0 24 24"/);
    assert.match(svg, /fill="#000000"/);
    assert.doesNotMatch(svg, /<(?:script|image|foreignObject)\b|\bhref\s*=/i);
    assert.match(card, new RegExp(`app\\.media\\.${name}`));
  }
});

test('registry includes all 20 first-batch service keys and common aliases', () => {
  assert.equal((registry.match(/key: ServiceIconKey\./g) || []).length, 20);
  for (const issuer of issuers) assert.match(registry, new RegExp(issuer));
  for (const alias of ['aliyun', 'tencentcloud', 'huaweicloud', 'baiduaicloud', 'volcengine', 'googleworkspace',
    'microsoftentra', 'amazonwebservices', 'chatgpt']) assert.match(registry, new RegExp(alias));
});

test('unknown issuers keep an initial-letter fallback instead of depending on network icons', () => {
  assert.match(card, /serviceInitial\(this\.item\.issuer\)/);
  assert.doesNotMatch(card, /https?:\/\/|fetch\(|request\(/);
  assert.doesNotMatch(registry, /https?:\/\/|fetch\(|request\(/);
});

test('add menu uses local leading icons for QR scan and manual entry', () => {
  const addMenu = page.slice(page.indexOf('  AddMenu()'), page.indexOf('  SwipeActions('));
  assert.match(addMenu, /startIcon: \$r\('app\.media\.menu_scan_qr'\)/);
  assert.match(addMenu, /startIcon: \$r\('app\.media\.menu_manual_entry'\)/);
  assert.equal((addMenu.match(/MenuItem\(/g) || []).length, 2);
  for (const name of ['menu_scan_qr', 'menu_manual_entry']) {
    const svg = read(`entry/src/main/resources/base/media/${name}.svg`);
    assert.match(svg, /<svg\b/);
    assert.doesNotMatch(svg, /<(?:script|image|foreignObject)\b|\bhref\s*=/i);
  }
});

test('preview mocks every first-batch service exactly once', () => {
  for (const issuer of issuers) {
    const escaped = issuer.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    assert.equal((mock.match(new RegExp(`issuer: '${escaped}'`, 'g')) || []).length, 1, issuer);
  }
  assert.equal((mock.match(/id: 'otp-/g) || []).length, 20);
  assert.match(mock, /issuer: 'Steam'.*code: 'R9K4Q'.*kind: OtpKind\.STEAM/);
  assert.equal((mock.match(/kind: OtpKind\.TOTP/g) || []).length, 19);
});
