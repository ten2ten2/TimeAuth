'use strict';

// Source/resource regression checks only; these do not compile or render ArkUI.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const page = fs.readFileSync(path.join(root,
  'entry/src/main/ets/features/authenticator/AuthenticatorPage.ets'), 'utf8');
const start = page.indexOf('  SwipeActions(item: OtpItem)');
const end = page.indexOf('  @Builder\n  EditorSheet()', start);
assert.ok(start >= 0 && end > start, 'SwipeActions builder must exist');
const actions = page.slice(start, end);
const edit = actions.slice(0, actions.indexOf('this.openEditor(item.id);'));
const remove = actions.slice(actions.indexOf('this.openEditor(item.id);'));

function count(text, pattern) {
  return (text.match(pattern) || []).length;
}

test('swipe actions contain two SVG images and no visible Edit/Delete labels', () => {
  assert.equal(count(actions, /\bButton\(/g), 2);
  assert.equal(count(actions, /\bImage\(/g), 2);
  assert.match(edit, /Image\(\$r\('app.media.action_edit'\)\)/);
  assert.match(remove, /Image\(\$r\('app.media.action_delete'\)\)/);
  assert.doesNotMatch(actions, /\bText\(|Button\(\$r|\.fontSize\(/);
});

test('icons use 24vp squares while full-height button touch targets remain 68vp wide', () => {
  assert.equal(count(actions, /\.width\(24\)/g), 2);
  assert.equal(count(actions, /\.height\(24\)/g), 2);
  assert.equal(count(actions, /\.width\(68\)/g), 2);
  assert.equal(count(actions, /\.height\('100%'\)/g), 3);
  assert.equal(count(actions, /\.padding\(0\)/g), 2);
  assert.equal(count(actions, /\.objectFit\(ImageFit.Contain\)/g), 2);
  assert.match(actions, /\.width\(152\)/);
});

test('icon-only buttons retain localized account-aware accessibility names', () => {
  assert.match(edit, /\.accessibilityText\(\$r\('app.string.auth_edit_accessibility', item.issuer, item.account\)\)/);
  assert.match(remove, /\.accessibilityText\(\$r\('app.string.auth_delete_accessibility', item.issuer, item.account\)\)/);
  assert.equal(count(actions, /\.accessibilityLevel\('no'\)/g), 2);
  assert.equal(count(actions, /\.draggable\(false\)/g), 2);
  assert.equal(count(actions, /stateEffect: true/g), 2);
});

test('edit follows the brand palette and delete keeps its high-contrast danger treatment', () => {
  assert.match(edit, /\.fillColor\(\$r\('app.color.brand'\)\)/);
  assert.match(edit, /\.backgroundColor\(\$r\('app.color.brand_soft'\)\)/);
  assert.match(remove, /\.fillColor\(Color.White\)/);
  assert.match(remove, /\.backgroundColor\(\$r\('app.color.danger'\)\)/);
});

test('action buttons still route to editor and deletion confirmation, never copy or directly delete', () => {
  assert.match(actions, /this.openEditor\(item.id\);/);
  assert.match(actions, /this.confirmDelete\(item.id\);/);
  assert.doesNotMatch(actions, /copyItem|onCopy|removeItem|splice\(/);
  assert.match(page, /actionAreaDistance: 0/);
  assert.doesNotMatch(page, /onAction\s*:/);
  const confirm = page.slice(page.indexOf('  private confirmDelete('), page.indexOf('  @Builder'));
  assert.match(confirm, /showAlertDialog\(/);
  assert.match(confirm, /value: \$r\('app.string.auth_cancel'\)/);
  assert.match(confirm, /value: \$r\('app.string.auth_delete'\)/);
  assert.match(confirm, /defaultFocus: true/);
});

test('action resources are local, square, fill-based SVGs without text or external content', () => {
  for (const name of ['action_edit', 'action_delete']) {
    const svg = fs.readFileSync(path.join(root,
      `entry/src/main/resources/base/media/${name}.svg`), 'utf8');
    assert.match(svg, /<svg\b/);
    assert.match(svg, /xmlns="http:\/\/www.w3.org\/2000\/svg"/);
    assert.match(svg, /width="24" height="24" viewBox="0 0 24 24"/);
    assert.match(svg, /<path\b/);
    assert.match(svg, /fill="#000000"/);
    assert.doesNotMatch(svg, /<(?:text|image|script|foreignObject)\b|\bhref\s*=|\bstroke\s*=/i);
    assert.match(svg, /<\/svg>\s*$/);
  }
});
