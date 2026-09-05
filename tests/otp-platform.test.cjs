'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const crypto = require('node:crypto');
const { stripTypeScriptTypes } = require('node:module');
const { load, draft, clone, deferred, read, corePath } = require('./otp-test-support.cjs');
const settle = () => new Promise(resolve => setImmediate(resolve));
const clean = source => source.replace(/^import[\s\S]*?;\r?\n/gm, '')
  .replace(/@(?:StorageLink|Watch)\([^)]*\)\s*/g, '').replace(/@State\s+/g, '').replace(/@Component\s*/g, '');

function pageFixture() {
  const api = load(); const data = []; const calls = { add: 0, update: 0, remove: [] };
  const intervals = new Map(), timers = new Map(), dialogs = [], clipboard = [];
  let sequence = 0, now = 59000, scan = deferred();
  const repo = {
    list: async () => clone(data), close: async () => {},
    add: async value => { calls.add++; const result = api.accountFromDraft(value, 'a'.repeat(32), now); data.push(result); return clone(result); },
    update: async (id,value) => { calls.update++; const result = api.accountFromDraft(value,id,now); data[data.findIndex(x=>x.id===id)]=result; return clone(result); },
    remove: async id => { calls.remove.push(id); data.splice(data.findIndex(x=>x.id===id),1); }
  };
  const sandbox = { ...api, __context: {}, __repo: repo, __copy: async code => { clipboard.push(code); return true; },
    $r: (key,...args) => ({ key,args }),
    Date: class extends Date { static now() { return now; } },
    ListScroller: class { closeAllSwipeActions() {} },
    OtpDeleteDialog: options => options,
    CustomDialogController: class { constructor(options) { this.options=options; dialogs.push(this); } open() {} close() {} },
    scanCore: { ScanType: { QR_CODE: 1 } },
    scanBarcode: { startScanForResult: async (_context,options) => { assert.equal(options.enableMultiMode,false); return scan.promise; } },
    getOtpRepository: () => repo,
    copySensitiveText: async (_context,code) => sandbox.__copy(code),
    otpErrorMessage: code => ({ key:code }),
    setTimeout: (fn,ms) => { const id=++sequence; timers.set(id,{fn,ms}); return id; },
    clearTimeout: id=>timers.delete(id),
    setInterval: fn=>{const id=++sequence; intervals.set(id,fn);return id;}, clearInterval:id=>intervals.delete(id)
  };
  const source = clean(read(corePath+'AuthenticatorPage.ets').split('  @Builder')[0])
    .replace('export struct AuthenticatorPage','class AuthenticatorPage') +
    '\ngetUIContext() { return { getHostContext: () => globalThis.__context }; }\n}\nglobalThis.Page = AuthenticatorPage;';
  vm.runInNewContext(stripTypeScriptTypes(source,{mode:'transform'}),sandbox);
  const page = new sandbox.Page(); page.aboutToAppear();
  async function unlock() { api.unlockAppSession(api.appSessionEpoch()); page.unlocked=true; await page.loadAccounts(); }
  function lock() { api.lockAppSession(); page.unlocked=false; page.onSessionChanged(); }
  return { api,page,data,calls,sandbox,intervals,timers,dialogs,clipboard,unlock,lock,
    setNow: value=>{now=value;}, scanResult: value=>scan.resolve(value), scanError: value=>scan.reject(value),
    seed: id=>data.push(api.accountFromDraft(draft(api),id,0)) };
}

test('controller does not read storage or start timers before system unlock', async()=>{
  const e=pageFixture(); assert.equal(e.page.ready,false); assert.equal(e.intervals.size,0);
  await e.unlock(); assert.equal(e.page.ready,true); assert.equal(e.page.items.length,0); assert.equal(e.intervals.size,1);
});
test('manual add opens a blank draft and writes only on explicit Save', async()=>{
  const e=pageFixture(); await e.unlock(); e.page.openManual();
  assert.equal(e.page.showEditor,true); assert.equal(e.page.editorDraft.secret,''); assert.equal(e.calls.add,0);
  await e.page.saveEdit(draft(e.api)); assert.equal(e.calls.add,1); assert.equal(e.page.items.length,1);
  assert.equal(e.page.showEditor,false); assert.equal(e.page.editorDraft.secret,'');
});
test('copy recomputes fresh code rather than copying displayed grouping', async()=>{
  const e=pageFixture(); e.seed('a'.repeat(32)); await e.unlock();
  const old=e.page.items[0].code; e.setNow(60000); await e.page.copyItem('a'.repeat(32));
  const expected=await new e.api.NativeOtpCrypto().generate(draft(e.api),2);
  assert.deepEqual(e.clipboard,[expected]); assert.notEqual(old.replace(/ /g,''),expected);
});
test('tapping exposed swipe content closes actions without copying', async()=>{
  const e=pageFixture(); e.seed('a'.repeat(32)); await e.unlock(); e.page.swipedItemId='a'.repeat(32);
  await e.page.copyItem('a'.repeat(32)); assert.deepEqual(e.clipboard,[]); assert.equal(e.page.swipedItemId,'');
});
test('delete dialog captures identity, Cancel does not delete, and positive action deletes exactly once', async()=>{
  const e=pageFixture(),id='a'.repeat(32); e.seed(id); await e.unlock(); e.page.confirmDelete(id);
  assert.deepEqual(e.dialogs[0].options.builder.message.args,['Example','demo@example.com']); assert.equal(e.calls.remove.length,0);
  e.dialogs[0].options.builder.onCancel(); assert.equal(e.calls.remove.length,0);
  e.page.confirmDelete(id); e.dialogs[1].options.builder.onDelete(); await settle();
  assert.deepEqual(e.calls.remove,[id]); e.dialogs[1].options.builder.onDelete(); await settle(); assert.equal(e.calls.remove.length,1);
});
test('stale dialog actions after cancellation cannot act on a newer dialog', async()=>{
  const e=pageFixture(),a='a'.repeat(32),b='b'.repeat(32); e.seed(a); e.seed(b); await e.unlock();
  e.page.confirmDelete(a); const old=e.dialogs[0].options; old.builder.onCancel(); e.page.confirmDelete(b);
  old.builder.onDelete(); old.cancel(); await settle(); assert.deepEqual(e.calls.remove,[]); assert.equal(e.page.deleteId,b);
  e.dialogs[1].options.builder.onDelete(); await settle(); assert.deepEqual(e.calls.remove,[b]);
});
test('stale dialog callback after locking cannot delete', async()=>{
  const e=pageFixture(),id='a'.repeat(32); e.seed(id); await e.unlock(); e.page.confirmDelete(id);
  const action=e.dialogs[0].options.builder.onDelete; e.lock(); await e.unlock(); action(); await settle();
  assert.deepEqual(e.calls.remove,[]);
});
test('a valid scan is reviewed but never automatically saved', async()=>{
  const e=pageFixture(); await e.unlock(); const task=e.page.scanQr();
  e.scanResult({originalValue:'otpauth://totp/Example:a?secret='+draft(e.api).secret+'&issuer=Example'}); await task;
  assert.equal(e.page.showEditor,true); assert.equal(e.page.editorDraft.issuer,'Example');
  assert.equal(e.calls.add,0); assert.equal(e.page.pendingScan,undefined);
});
test('scan returning during native background is deferred until successful unlock and read', async()=>{
  const e=pageFixture(); await e.unlock(); const task=e.page.scanQr(); e.lock();
  e.scanResult({originalValue:'otpauth://totp/Example:a?secret='+draft(e.api).secret}); await task;
  assert.equal(e.page.showEditor,false); assert.ok(e.page.pendingScan); assert.equal(e.calls.add,0);
  await e.unlock(); assert.equal(e.page.showEditor,true); assert.equal(e.page.pendingScan,undefined);
});
test('pending scan expires without persisting the key', async()=>{
  const e=pageFixture(); await e.unlock(); const task=e.page.scanQr(); e.lock();
  e.scanResult({originalValue:'otpauth://totp/Example:a?secret='+draft(e.api).secret}); await task;
  [...e.timers.values()].find(x=>x.ms===120000).fn(); await e.unlock();
  assert.equal(e.page.showEditor,false); assert.equal(e.calls.add,0);
});
test('malformed scan and migration code produce errors rather than opening a secret editor', async()=>{
  for(const uri of ['https://example.com','otpauth-migration://offline?data=secret']){
    const e=pageFixture(); await e.unlock(); const task=e.page.scanQr(); e.scanResult({originalValue:uri}); await task;
    assert.equal(e.page.showEditor,false); assert.equal(e.calls.add,0); assert.equal(e.page.feedbackVisible,true);
  }
});
test('native scan cancellation is silent and disposing ignores a late scan', async()=>{
  let e=pageFixture(); await e.unlock(); let task=e.page.scanQr(); e.scanError({code:1000500002}); await task;
  assert.equal(e.page.feedbackVisible,false);
  e=pageFixture(); await e.unlock(); task=e.page.scanQr(); e.page.aboutToDisappear();
  e.scanResult({originalValue:'otpauth://totp/Example:a?secret='+draft(e.api).secret}); await task;
  assert.equal(e.page.pendingScan,undefined); assert.equal(e.page.showEditor,false);
});
test('lock clears timer, rows, edit secrets and pending deletion', async()=>{
  const e=pageFixture(),id='a'.repeat(32); e.seed(id); await e.unlock(); e.page.openEditor(id);
  assert.ok(e.page.editorDraft.secret); e.lock(); assert.equal(e.intervals.size,0);
  assert.equal(e.page.items.length,0); assert.equal(e.page.editorDraft.secret,''); assert.equal(e.page.ready,false);
});
test('native clipboard failure never reports successful copy', async()=>{
  const e=pageFixture(),id='a'.repeat(32); e.seed(id); await e.unlock(); e.sandbox.__copy=async()=>{throw new Error('native');};
  await e.page.copyItem(id); assert.equal(e.page.feedbackText.key,'app.string.security_copy_failed');
});
test('countdown updates preserve observed row identity and stable ID', async()=>{
  const e=pageFixture(),id='a'.repeat(32); e.seed(id); await e.unlock(); const row=e.page.items[0];
  e.setNow(59001); await e.page.session.refresh(); assert.equal(e.page.items[0],row); assert.equal(row.id,id);
});

function deviceFixture(available=[4,2,1]) {
  const instances=[],timers=new Map(); let sequence=0;
  const userAuth={UserAuthType:{FINGERPRINT:4,FACE:2,PIN:1},AuthTrustLevel:{ATL2:20000},UserAuthResultCode:{SUCCESS:12500000},
    getAvailableStatus(type,level){assert.equal(level,20000);if(!available.includes(type))throw new Error('not enrolled');},
    getUserAuthInstance(params,widget){const instance={params,widget,offCount:0,cancelCount:0,
      on(_event,cb){this.callback=cb;},off(){this.offCount++;},start(){this.started=true;},cancel(){this.cancelCount++;}};
      instances.push(instance);return instance;}};
  const sandbox={userAuth,cryptoFramework:{createRandom:()=>({generateRandomSync:n=>({data:new Uint8Array(crypto.randomBytes(n))})})},
    setTimeout:(fn)=>{const id=++sequence;timers.set(id,fn);return id;},clearTimeout:id=>timers.delete(id)};
  const source=read('entry/src/main/ets/security/DeviceUnlock.ets').replace(/^import.*;\n/gm,'').replace('export class','class');
  vm.runInNewContext(stripTypeScriptTypes(source+'\nglobalThis.DeviceUnlock=DeviceUnlock;',{mode:'transform'}),sandbox);
  return {request:new sandbox.DeviceUnlock(),instances,timers};
}
test('system auth supports enrolled types and random challenge; only SUCCESS resolves true',async()=>{
  const e=deviceFixture([1]); const promise=e.request.verify('Unlock'); const i=e.instances[0];
  assert.equal(i.params.challenge.length,32); assert.deepEqual(Array.from(i.params.authType),[1]);
  i.callback.onResult({result:12500000}); assert.equal(await promise,true); assert.equal(i.offCount,1); assert.equal(e.timers.size,0);
});
test('no available authentication type fails closed without creating a widget',async()=>{
  const e=deviceFixture([]); assert.equal(await e.request.verify('Unlock'),false); assert.equal(e.instances.length,0);
});
test('cancel, timeout and failed result never unlock',async()=>{
  for(const operation of ['cancel','timeout','failed']){
    const e=deviceFixture();const promise=e.request.verify('Unlock');
    if(operation==='cancel')e.request.cancel(); else if(operation==='timeout')[...e.timers.values()][0]();
    else e.instances[0].callback.onResult({result:12500001});
    assert.equal(await promise,false); assert.equal(e.timers.size,0);
  }
});
test('replacing an auth request cancels old one and ignores its late SUCCESS',async()=>{
  const e=deviceFixture(); const old=e.request.verify('old'); const oldCallback=e.instances[0].callback;
  const next=e.request.verify('new'); assert.equal(await old,false); oldCallback.onResult({result:12500000});
  e.instances[1].callback.onResult({result:12500001}); assert.equal(await next,false);
});
test('background invalidates authentication epochs and foreground alone never unlocks',()=>{
  const a=load(),epoch=a.appSessionEpoch(); assert.equal(a.isAppSessionUnlocked(),false);
  a.setAppSessionForeground(false); assert.equal(a.unlockAppSession(epoch),false);
  a.setAppSessionForeground(true); assert.equal(a.isAppSessionUnlocked(),false); assert.equal(a.unlockAppSession(epoch),false);
  assert.equal(a.unlockAppSession(a.appSessionEpoch()),true); a.lockAppSession(); assert.equal(a.isAppSessionUnlocked(),false);
});
