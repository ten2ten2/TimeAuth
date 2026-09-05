'use strict';
// Resource and source checks, not native ArkUI gesture/render tests.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {read,corePath}=require('./otp-test-support.cjs');
const page=read(corePath+'AuthenticatorPage.ets');
const start=page.indexOf('  SwipeActions(item: OtpViewItem)');
const end=page.indexOf('  @Builder\n  EditorSheet()',start);
assert.ok(start>=0 && end>start);
const actions=page.slice(start,end);
const edit=actions.slice(0,actions.indexOf('this.openEditor(item.id);'));
const remove=actions.slice(actions.indexOf('this.openEditor(item.id);'));
const count=(text,pattern)=>(text.match(pattern)||[]).length;
test('swipe actions contain two SVG images and no visible Edit/Delete labels',()=>{
  assert.equal(count(actions,/\bButton\(/g),2);assert.equal(count(actions,/\bImage\(/g),2);
  assert.match(edit,/app.media.action_edit/);assert.match(remove,/app.media.action_delete/);
  assert.doesNotMatch(actions,/\bText\(|Button\(\$r|\.fontSize\(/);
});
test('24vp icons retain full-height 68vp targets and 152vp total action width',()=>{
  for(const pattern of [/\.width\(24\)/g,/\.height\(24\)/g,/\.width\(68\)/g,/\.padding\(0\)/g])assert.equal(count(actions,pattern),2);
  assert.equal(count(actions,/\.height\('100%'\)/g),3);assert.match(actions,/\.width\(152\)/);
});
test('icons retain localized account-aware accessibility names and pressed feedback',()=>{
  assert.match(edit,/auth_edit_accessibility', item.issuer, item.account/);
  assert.match(remove,/auth_delete_accessibility', item.issuer, item.account/);
  assert.equal(count(actions,/\.accessibilityLevel\('no'\)/g),2);
  assert.equal(count(actions,/\.draggable\(false\)/g),2);assert.equal(count(actions,/stateEffect: true/g),2);
});
test('edit follows brand palette and delete retains danger treatment',()=>{
  assert.match(edit,/\.fillColor\(\$r\('app.color.brand'\)\)/);assert.match(edit,/app.color.brand_soft/);
  assert.match(remove,/\.fillColor\(Color.White\)/);assert.match(remove,/app.color.danger/);
});
test('swipe buttons do not copy or directly remove; deletion has a guarded confirmation',()=>{
  assert.match(actions,/this.openEditor\(item.id\)/);assert.match(actions,/this.confirmDelete\(item.id\)/);
  assert.doesNotMatch(actions,/copyItem|onCopy|\.remove\(|splice\(/);
  assert.match(page,/actionAreaDistance: 0/);assert.doesNotMatch(page,/onAction\s*:/);
  assert.match(page,/new CustomDialogController/);assert.match(page,/id !== this.deleteId/);
  assert.match(page,/token !== this.deleteToken/);assert.match(page,/revision !== this.revision/);
  const dialog=read(corePath+'OtpDeleteDialog.ets');
  assert.match(dialog,/auth_cancel/);assert.match(dialog,/auth_delete/);assert.match(dialog,/\.defaultFocus\(true\)/);
});
test('action resources are local square fill-based SVGs without external content',()=>{
  for(const name of ['action_edit','action_delete']){
    const svg=read(`entry/src/main/resources/base/media/${name}.svg`);
    assert.match(svg,/width="24" height="24" viewBox="0 0 24 24"/);
    assert.match(svg,/<path\b/);assert.match(svg,/fill="#000000"/);
    assert.doesNotMatch(svg,/<(?:text|image|script|foreignObject)\b|\bhref\s*=|\bstroke\s*=/i);
  }
});
