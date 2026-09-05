'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {read,root,corePath}=require('./otp-test-support.cjs');
const page=read(corePath+'AuthenticatorPage.ets'),card=read('entry/src/main/ets/components/OtpCard.ets');
test('cards retain rounded outer clipping, a single copy button and Apple-only optical offset',()=>{
  assert.match(card,/Column\(\)/); assert.match(card,/radius: AppRadius.large/);assert.match(card,/\.clip\(true\)/);
  assert.equal((card.match(/Button\(/g)||[]).length,1);assert.match(card,/\.backgroundColor\(Color.Transparent\)/);
  assert.match(card,/ServiceIconKey.APPLE \? -1 : 0/);assert.match(card,/\.translate\(\{ y: this.serviceIconOffsetY\(\) \}\)/);
  assert.match(card,/@ObjectLink item: OtpViewItem/);assert.match(card,/this.onCopy\(/);
});
test('stable observed card IDs do not rebuild during each countdown refresh',()=>{
  assert.match(page,/\(item: OtpViewItem\) => item.id/);assert.doesNotMatch(page,/otpPreviewRenderKey|remaining.*\+.*id/);
  assert.match(read(corePath+'OtpViewItem.ets'),/@Observed/);
});
test('original header and add actions remain without search or theme shortcut',()=>{
  assert.match(page,/title: \$r\('app.string.auth_title'\)/);assert.match(page,/Button\('\+'\)/);
  assert.doesNotMatch(page,/SearchField|searchText|ThemePreference|auth_feature_later_feedback/);
});
test('editor protects setup-key input and shows backup/parameter limitations',()=>{
  const editor=read(corePath+'OtpEditor.ets');
  assert.match(editor,/InputType.Password/);assert.match(editor,/enableAutoFill\(false\)/);assert.match(editor,/CopyOptions.None/);
  assert.match(editor,/auth_live_backup_warning/);assert.match(editor,/auth_live_parameters_notice/);
  assert.doesNotMatch(editor,/console\.|hilog\.|onCopy/);
});
test('system auth gates both app visibility and encrypted repository access',()=>{
  const app=read('entry/src/main/ets/app/AppRoot.ets'),unlock=read('entry/src/main/ets/features/onboarding/UnlockPage.ets');
  assert.match(app,/Visibility.Hidden/);assert.match(app,/\.enabled\(this.unlocked\)/);
  assert.match(unlock,/await this.request.verify/);assert.match(unlock,/unlockAppSession\(epoch\)/);
  assert.doesNotMatch(unlock,/unlock_mock|onUnlock\(\)|showFallback|TextInput\(/);
  const ability=read('entry/src/main/ets/entryability/EntryAbility.ets');
  assert.match(ability,/setAppSessionForeground\(false\)/);assert.match(ability,/lockAppSession\(\)/);
});
test('manifest adds system verification permission but no network or broad storage permissions',()=>{
  const manifest=JSON.parse(read('entry/src/main/module.json5'));
  const permissions=manifest.module.requestPermissions.map(x=>x.name);
  assert.deepEqual(permissions,['ohos.permission.PRIVACY_WINDOW','ohos.permission.ACCESS_BIOMETRIC']);
});
test('all live resource keys are translated exactly once with matching placeholders',()=>{
  let expected;const keys=new Set();
  for(const locale of ['base','zh_Hans','zh_Hant_TW','zh_Hant_HK']){
    const entries=JSON.parse(read(`entry/src/main/resources/${locale}/element/authenticator_live.json`)).string;
    const names=entries.map(x=>x.name);assert.equal(new Set(names).size,names.length);
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
test('privacy and security surfaces no longer advertise mock unlock or storage',()=>{
  assert.match(read('entry/src/main/ets/features/settings/AboutPage.ets'),/auth_live_privacy_body/);
  const settings=read('entry/src/main/ets/features/settings/SettingsPage.ets');
  assert.match(settings,/auth_live_security_title/);assert.match(settings,/auth_live_local_data_detail/);
  assert.match(settings,/auth_live_not_available/);
});
