'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {read,corePath}=require('./otp-test-support.cjs');
const registry=read(corePath+'ServiceIconRegistry.ets');
const card=read('entry/src/main/ets/components/OtpCard.ets');
const page=read(corePath+'AuthenticatorPage.ets');
const serviceResources=[
  'alibaba_cloud','tencent_cloud','huawei_cloud','baidu_ai_cloud','volcano_engine',
  'google','microsoft','github','apple','aws','cloudflare','steam','discord','dropbox',
  'slack','bitwarden','1password','gitlab','proton','openai'];
test('all 20 local service SVGs and their resource bindings are retained',()=>{
  assert.equal(serviceResources.length,20);
  for(const name of serviceResources){
    const svg=read(`entry/src/main/resources/base/media/service_${name}.svg`);
    assert.match(svg,/<svg\b/);assert.match(svg,/viewBox="0 0 24 24"/);assert.match(svg,/fill="#000000"/);
    assert.doesNotMatch(svg,/<(?:script|image|foreignObject)\b|\bhref\s*=/i);
    assert.ok(card.includes(`app.media.service_${name}`));
  }
});
test('registry retains first-batch keys and common aliases',()=>{
  assert.equal((registry.match(/key: ServiceIconKey\./g)||[]).length,20);
  for(const alias of ['aliyun','tencentcloud','huaweicloud','baiduaicloud','volcengine',
    'googleworkspace','microsoftentra','amazonwebservices','chatgpt'])assert.ok(registry.includes(alias));
});
test('unknown issuers retain neutral initial fallback without network loading',()=>{
  assert.match(card,/serviceInitial\(this.item.issuer\)/);assert.match(card,/app.color.surface_secondary/);
  assert.doesNotMatch(card,/https?:\/\/|fetch\(|request\(/);assert.doesNotMatch(registry,/https?:\/\/|fetch\(|request\(/);
});
test('add menu retains exactly two leading SVG icons',()=>{
  const menu=page.slice(page.indexOf('  AddMenu()'),page.indexOf('  SwipeActions('));
  assert.match(menu,/startIcon: \$r\('app.media.menu_scan_qr'\)/);
  assert.match(menu,/startIcon: \$r\('app.media.menu_manual_entry'\)/);
  assert.equal((menu.match(/MenuItem\(/g)||[]).length,2);
  for(const name of ['menu_scan_qr','menu_manual_entry']){
    const svg=read(`entry/src/main/resources/base/media/${name}.svg`);
    assert.match(svg,/<svg\b/);assert.doesNotMatch(svg,/<(?:script|image|foreignObject)\b|\bhref\s*=/i);
  }
});
test('real runtime starts empty rather than seeding demonstration services',()=>{
  assert.match(page,/private items: OtpViewItem\[\] = \[\]/);
  assert.doesNotMatch(page,/mockRepository|AuthenticatorPreviewStore|demo@|getOtpItems/);
  assert.doesNotMatch(read('entry/src/main/ets/data/MockRepository.ets'),/getOtpItems|id: 'otp-/);
  assert.doesNotMatch(read('entry/src/main/ets/data/Repository.ets'),/getOtpItems/);
  assert.doesNotMatch(read(corePath+'OtpCore.ets'),/resolveServiceIcon|ServiceIconKey/);
});
