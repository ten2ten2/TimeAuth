'use strict';
// Executes the actual session/controller logic with fault-injectable I/O, not native ArkUI rendering.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { load, draft, clone, deferred, read, corePath } = require('./otp-test-support.cjs');

function setup(options = {}) {
  const a = load();
  let time = options.time ?? 29000;
  const id = 'a'.repeat(32), other = 'b'.repeat(32);
  let stored = options.empty ? [] : [a.accountFromDraft(draft(a), id, 100)];
  const updates = [], calls = [];
  const hooks = {};
  const repo = {
    list: async () => hooks.list ? hooks.list() : clone(stored),
    add: async value => {
      if (hooks.add) return hooks.add(value);
      const item = a.accountFromDraft(value,other,200); stored.push(clone(item)); return item;
    },
    update: async (key,value) => {
      if (hooks.update) return hooks.update(key,value);
      const item = a.accountFromDraft(value,key,100);
      stored = stored.map(x => x.id === key ? clone(item) : x); return item;
    },
    remove: async key => {
      if (hooks.remove) return hooks.remove(key);
      stored = stored.filter(x => x.id !== key);
    },
    close: async () => { calls.push('close'); }
  };
  const provider = { generate: async (value,counter) => {
    calls.push(counter);
    return hooks.generate ? hooks.generate(value,counter) : String(counter).padStart(6,'0');
  }};
  const session = new a.OtpSession(repo,provider,()=>time,snapshots=>updates.push(clone(snapshots)));
  return {a,id,other,session,repo,hooks,updates,calls,stored:()=>clone(stored),setTime:value=>{time=value;},last:()=>updates.at(-1)};
}

test('new install is empty; no preview accounts are created', async () => {
  const e=setup({empty:true}); await e.session.open(); assert.deepEqual(e.last(),[]); assert.deepEqual(e.stored(),[]);
});
test('snapshots expose labels and codes, never secrets or credential identities', async () => {
  const e=setup(); await e.session.open();
  assert.equal(e.last()[0].code,'000000'); assert.equal(e.last()[0].remaining,1);
  assert.doesNotMatch(JSON.stringify(e.updates),/secret|GEZDG|credential/);
});
test('HMAC is cached within a time step while countdown comes from absolute time', async () => {
  const e=setup({time:1000}); await e.session.open();
  e.setTime(14000); await e.session.refresh(); e.setTime(29000); await e.session.refresh();
  assert.equal(e.calls.filter(x=>typeof x==='number').length,1); assert.equal(e.last()[0].remaining,1);
  e.setTime(30000); await e.session.refresh(); assert.equal(e.last()[0].code,'000001');
});
test('expired codes disappear before slow new HMAC completes', async () => {
  const e=setup(); await e.session.open();
  const wait=deferred(); e.hooks.generate=()=>wait.promise; e.setTime(30000);
  const refreshing=e.session.refresh(); assert.equal(e.last()[0].code,'');
  wait.resolve('000001'); await refreshing; assert.equal(e.last()[0].code,'000001');
});
test('refresh handles time jumps forwards and backwards, not timer decrement drift', async () => {
  const e=setup(); await e.session.open(); e.setTime(30000000); await e.session.refresh();
  assert.equal(e.last()[0].code,'001000'); e.setTime(0); await e.session.refresh();
  assert.equal(e.last()[0].code,'000000'); assert.equal(e.last()[0].remaining,30);
});
test('each account gets its own period and code format', async () => {
  const e=setup({time:59000}); await e.session.open(); await e.session.save('',draft(e.a,{period:60,digits:8,issuer:'Second'}));
  assert.equal(e.last().length,2); assert.equal(e.last()[0].period,30); assert.equal(e.last()[1].period,60);
  assert.equal(e.last()[0].code,'000001'); assert.equal(e.last()[1].code,'000000');
});
test('failed HMAC never leaves a stale usable code and is retried', async () => {
  const e=setup(); await e.session.open(); e.setTime(30000);
  e.hooks.generate=async()=>{throw new Error('failed');}; await e.session.refresh();
  assert.equal(e.last()[0].code,''); assert.equal(e.last()[0].failed,true);
  delete e.hooks.generate; await e.session.refresh(); assert.equal(e.last()[0].code,'000001');
});
test('fresh copy uses the tap-time counter even before the display timer ticks', async () => {
  const e=setup(); await e.session.open(); e.setTime(30000);
  assert.equal(await e.session.freshCode(e.id),'000001'); assert.equal(e.last()[0].code,'000000');
});
test('fresh copy retries HMAC that crosses a time-step boundary', async () => {
  const e=setup(); await e.session.open(); let count=0;
  e.hooks.generate=async(_account,counter)=>{ if(count++===0)e.setTime(30000);return String(counter).padStart(6,'0'); };
  assert.equal(await e.session.freshCode(e.id),'000001'); assert.equal(count,2);
});
test('closing a session cancels late copy and refresh publication', async () => {
  const e=setup(); await e.session.open(); const wait=deferred(); e.hooks.generate=()=>wait.promise;
  const copying=e.session.freshCode(e.id); e.session.close(); wait.resolve('123456');
  await assert.rejects(copying,{code:'LOCKED'}); assert.deepEqual(e.last(),[]);
  assert.throws(()=>e.session.draft(e.id),{code:'LOCKED'});
});
test('a read completed after close cannot resurrect accounts', async () => {
  const e=setup(); const wait=deferred(); e.hooks.list=()=>wait.promise;
  const opening=e.session.open(); e.session.close(); wait.resolve(e.stored()); await opening;
  assert.deepEqual(e.last(),[]); await assert.rejects(e.session.freshCode(e.id),{code:'LOCKED'});
});
test('a database read failure is propagated rather than presented as a successful empty vault', async () => {
  const e=setup(); e.hooks.list=async()=>{throw new Error('disk inaccessible');};
  await assert.rejects(e.session.open()); assert.equal(e.updates.length,0);
});
test('edit drafts are detached and cancellation does not mutate the live/stored account', async () => {
  const e=setup(); await e.session.open(); const value=e.session.draft(e.id);value.issuer='Unsaved';value.secret='';
  assert.equal(e.session.draft(e.id).issuer,'Example');assert.equal(e.stored()[0].issuer,'Example');
});
test('failed save leaves previous code, metadata and persistent account intact', async () => {
  const e=setup(); await e.session.open(); e.hooks.update=async()=>{throw new Error('disk full');};
  await assert.rejects(e.session.save(e.id,draft(e.a,{issuer:'Changed'})));
  assert.equal(e.last()[0].issuer,'Example');assert.equal(e.stored()[0].issuer,'Example');
});
test('committed edit updates metadata without changing the stable row ID', async () => {
  const e=setup(); await e.session.open(); await e.session.save(e.id,draft(e.a,{issuer:'Changed'}));
  assert.equal(e.last()[0].issuer,'Changed');assert.equal(e.last()[0].id,e.id);
  assert.equal(e.stored()[0].issuer,'Changed');
});
test('failed delete keeps the existing account; successful delete removes only the stable ID', async () => {
  const e=setup();await e.session.open();await e.session.save('',draft(e.a,{issuer:'Second',period:60}));
  e.hooks.remove=async()=>{throw new Error('disk full');}; await assert.rejects(e.session.remove(e.id));
  assert.equal(e.last().length,2);delete e.hooks.remove;await e.session.remove(e.id);
  assert.deepEqual(e.last().map(x=>x.id),[e.other]);
});
test('clear-on-lock does not erase the persistent accounts; reopening reloads them', async () => {
  const e=setup();await e.session.open(); e.session.close();
  assert.ok(e.stored()[0].secret.length>0); await e.session.open();assert.equal(e.last().length,1);
});
test('mutations are serialized and late accepted saves cannot resurrect locked UI', async () => {
  const e=setup();await e.session.open();const wait=deferred();
  e.hooks.update=()=>wait.promise;const saving=e.session.save(e.id,draft(e.a,{issuer:'Changed'}));
  await assert.rejects(e.session.remove(e.id),{code:'BUSY'});
  e.session.close();wait.resolve(e.a.accountFromDraft(draft(e.a,{issuer:'Changed'}),e.id,100));await saving;
  assert.deepEqual(e.last(),[]);
});
test('an old refresh cannot overwrite a code after its seed was edited', async () => {
  const e=setup();await e.session.open(); const wait=deferred();let calls=0;
  e.hooks.generate=async()=>++calls===1?wait.promise:'888888';e.setTime(30000);
  const old=e.session.refresh();await e.session.save(e.id,draft(e.a,{issuer:'Changed'}));
  wait.resolve('111111');await old;assert.equal(e.last()[0].code,'888888');
});
test('view items update in place, leaving list IDs stable across second/period changes', () => {
  const a=load();const snapshot={id:'x',issuer:'Example',account:'user',kind:a.OtpKind.TOTP,code:'001234',remaining:30,period:30,failed:false};
  const item=new a.OtpViewItem(snapshot);item.update({...snapshot,code:'005678',remaining:29});
  assert.equal(item.id,'x');assert.equal(item.code,'005 678');assert.equal(item.remainingSeconds,29);
});
