'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {read,root,corePath}=require('./otp-test-support.cjs');
const page=read(corePath+'AuthenticatorPage.ets');
const card=read('entry/src/main/ets/components/OtpCard.ets');

test('cards retain rounded clipping, full-card copy, and a separate HOTP next-code control',()=>{
  assert.match(card,/Column\(\)/); assert.match(card,/radius: AppRadius.large/);assert.match(card,/\.clip\(true\)/);
  assert.equal((card.match(/\bButton\(\{/g)||[]).length,2);
  assert.match(card,/Stack\(\{ alignContent: Alignment.TopEnd \}\)/);
  assert.match(card,/this\.onCopy\(this\.item\.code, this\.item\.issuer\)/);
  assert.match(card,/HOTPAdvanceButton\(\)/);assert.match(card,/app\.media\.action_next/);
  assert.match(card,/this\.onAdvance\(this\.item\.id\)/);
  assert.match(card,/this\.item\.kind === OtpKind\.HOTP/);
  assert.match(card,/HOTP #\$\{this\.item\.counter\}/);
  assert.match(card,/ServiceIconKey.APPLE \? -1 : 0/);
  assert.match(card,/@ObjectLink item: OtpViewItem/);
});

test('HOTP next control is not nested inside the copy button and keeps its own accessibility label',()=>{
  const copyStart=card.indexOf('Button({ type: ButtonType.Normal');
  const copyEnd=card.indexOf('if (this.item.kind === OtpKind.HOTP)', copyStart);
  const copy=card.slice(copyStart,copyEnd);
  assert.doesNotMatch(copy,/action_next|onAdvance/);
  assert.match(card,/auth_live_hotp_next_accessibility/);
  const svg=read('entry/src/main/resources/base/media/action_next.svg');
  assert.match(svg,/width="24" height="24" viewBox="0 0 24 24"/);
  assert.match(svg,/fill="#000000"/);
  assert.doesNotMatch(svg,/<(?:text|image|script|foreignObject)\b|\bhref\s*=/i);
});

test('stable observed card IDs carry HOTP counters without rebuilding rows',()=>{
  assert.match(page,/\(item: OtpViewItem\) => item.id/);
  const view=read(corePath+'OtpViewItem.ets');
  assert.match(view,/@Observed/);assert.match(view,/counter: number/);assert.match(view,/this\.counter = snapshot\.counter/);
});

test('original header and two add actions remain without search/theme shortcuts',()=>{
  assert.match(page,/title: \$r\('app.string.auth_title'\)/);assert.match(page,/Button\('\+'\)/);
  const menu=page.slice(page.indexOf('  AddMenu()'),page.indexOf('  SwipeActions('));
  assert.equal((menu.match(/MenuItem\(/g)||[]).length,2);
  assert.doesNotMatch(page,/SearchField|searchText|ThemePreference|auth_feature_later_feedback/);
});

test('editor supports TOTP, HOTP and Steam while protecting secret input',()=>{
  const editor=read(corePath+'OtpEditor.ets');
  assert.match(editor,/\{ value: 'TOTP' \}, \{ value: 'HOTP' \}, \{ value: 'Steam Guard' \}/);
  assert.match(editor,/auth_live_hotp_counter/);assert.match(editor,/auth_live_hotp_counter_notice/);
  assert.match(editor,/InputType.Password/);assert.match(editor,/enableAutoFill\(false\)/);assert.match(editor,/CopyOptions.None/);
  assert.match(editor,/auth_live_backup_warning/);assert.doesNotMatch(editor,/console\.|hilog\.|onCopy/);
});

test('controller has explicit HOTP advancement and copy never routes through it',()=>{
  assert.match(page,/private async advanceHOTP\(id: string\)/);
  assert.match(page,/await this\.session\.advanceHOTP\(id\)/);
  assert.match(page,/auth_live_hotp_advanced/);
  const copy=page.slice(page.indexOf('  private async copyItem('),page.indexOf('  private openManual('));
  assert.match(copy,/freshCode\(id\)/);assert.doesNotMatch(copy,/advanceHOTP|advanceCounter/);
});

test('all live + HOTP resource keys are translated exactly once with matching placeholders',()=>{
  let expected;const keys=new Set();
  for(const locale of ['base','zh_Hans','zh_Hant_TW','zh_Hant_HK']){
    const live=JSON.parse(read(`entry/src/main/resources/${locale}/element/authenticator_live.json`)).string;
    const hotp=JSON.parse(read(`entry/src/main/resources/${locale}/element/authenticator_hotp.json`)).string;
    const entries=live.concat(hotp);const names=entries.map(x=>x.name);
    assert.equal(new Set(names).size,names.length);
    const signature=entries.map(x=>[x.name,(x.value.match(/%s/g)||[]).length]);
    if(!expected){expected=signature;names.forEach(name=>keys.add(name));}else assert.deepEqual(signature,expected);
    entries.forEach(x=>assert.ok(x.value.length>0));
  }
  function walk(dir){for(const file of fs.readdirSync(dir,{withFileTypes:true})){
    const target=path.join(dir,file.name);if(file.isDirectory())walk(target);
    else if(file.name.endsWith('.ets')){for(const [,key] of fs.readFileSync(target,'utf8').matchAll(/app.string.(auth_live_\w+)/g))assert.ok(keys.has(key),key);}
  }}
  walk(path.join(root,'entry/src/main/ets'));
});
