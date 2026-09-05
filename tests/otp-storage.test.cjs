'use strict';
// Native encryption itself requires device verification. These tests exercise repository calls and failure behavior.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { load, draft, clone, deferred } = require('./otp-test-support.cjs');

function setup() {
  const e={ rows:[],configs:[],sql:[],closedResults:0,closes:0,version:0 };
  class Predicates { constructor(table){this.table=table;} equalTo(key,value){this.key=key;this.value=value;return this;} }
  const store={
    get version(){return e.version;},set version(value){e.version=value;},
    executeSql: async sql=>{e.sql.push(sql);if(e.failSchema)throw new Error('schema');},
    querySql: async sql=>{
      e.sql.push(sql);if(e.failRead)throw new Error('native error including secret GEZDG');
      const rows=clone(e.rows);let index=-1;
      return {rowCount:rows.length,goToNextRow:()=>++index<rows.length,getColumnIndex:name=>name,
        getString:key=>rows[index][key],getLong:key=>rows[index][key],close:()=>{e.closedResults++;}};
    },
    insert: async(table,values)=>{
      if(e.waitInsert)await e.waitInsert.promise;
      if(e.failWrite)throw new Error('native secret GEZDG');
      assert.equal(table,'otp_accounts');assert.ok(!e.rows.some(x=>x.id===values.id||x.credential_key===values.credential_key));
      e.rows.push(clone(values));return e.rows.length;
    },
    update: async(values,predicate)=>{
      if(e.failWrite)throw new Error('native error');
      const index=e.rows.findIndex(x=>x.id===predicate.value);if(index<0)return 0;
      e.rows[index]={...e.rows[index],...clone(values)};return 1;
    },
    delete: async predicate=>{
      if(e.failWrite)throw new Error('native error');
      const length=e.rows.length;e.rows=e.rows.filter(x=>x.id!==predicate.value);return length-e.rows.length;
    },
    close:async()=>{e.closes++;}
  };
  const a=load({relationalStore:{SecurityLevel:{S3:3},RdbPredicates:Predicates,getRdbStore:async(_ctx,config)=>{
    e.configs.push(clone(config));if(e.failOpen)throw new Error('key missing');return store;
  }}});
  a.unlockAppSession(a.appSessionEpoch());
  return Object.assign(e,{a,repo:new a.EncryptedOtpRepository({})});
}

test('native store is always encrypted, S3, and initially empty',async()=>{
  const e=setup();assert.deepEqual(clone(await e.repo.list()),[]);
  assert.equal(e.configs[0].encrypt,true);assert.equal(e.configs[0].securityLevel,3);
  assert.equal(e.rows.length,0);assert.ok(e.sql.every(x=>!/(DROP|REPLACE)/.test(x)));
});
test('saved account survives repository close and reload; IDs and time metadata persist',async()=>{
  const e=setup();const item=await e.repo.add(draft(e.a));await e.repo.close();
  assert.deepEqual(clone(await e.repo.list()),[clone(item)]);assert.match(item.id,/^[a-f0-9]{32}$/);
  assert.equal(e.configs.length,2);
});
test('duplicate seed/settings cannot create a second account even with a different display name',async()=>{
  const e=setup();await e.repo.add(draft(e.a));
  await assert.rejects(e.repo.add(draft(e.a,{issuer:'Other'})),{code:'DUPLICATE'});assert.equal(e.rows.length,1);
});
test('concurrent duplicate adds are serialized before uniqueness checks',async()=>{
  const e=setup();const outcomes=await Promise.allSettled([e.repo.add(draft(e.a)),e.repo.add(draft(e.a))]);
  assert.equal(outcomes.filter(x=>x.status==='fulfilled').length,1);assert.equal(e.rows.length,1);
});
test('duplicate edit is rejected without changing either account',async()=>{
  const e=setup();const one=await e.repo.add(draft(e.a));const two=await e.repo.add(draft(e.a,{period:60}));
  const before=clone(e.rows);await assert.rejects(e.repo.update(two.id,draft(e.a)),{code:'DUPLICATE'});
  assert.deepEqual(e.rows,before);assert.ok(one.id!==two.id);
});
test('edit preserves identity/order; deletion targets a stable ID rather than index or issuer',async()=>{
  const e=setup();const one=await e.repo.add(draft(e.a));const two=await e.repo.add(draft(e.a,{period:60}));
  const edited=await e.repo.update(one.id,draft(e.a,{issuer:'Work'}));assert.equal(edited.createdAt,one.createdAt);
  await e.repo.remove(two.id);const rows=await e.repo.list();assert.equal(rows.length,1);assert.equal(rows[0].id,one.id);
});
test('failed writes never publish or overwrite stored state and do not poison future operations',async()=>{
  const e=setup();const one=await e.repo.add(draft(e.a));const before=clone(e.rows);e.failWrite=true;
  await assert.rejects(e.repo.update(one.id,draft(e.a,{issuer:'Changed'})),{code:'STORAGE'});
  await assert.rejects(e.repo.remove(one.id),{code:'STORAGE'});assert.deepEqual(e.rows,before);
  e.failWrite=false;await e.repo.update(one.id,draft(e.a,{issuer:'Changed'}));assert.equal((await e.repo.list())[0].issuer,'Changed');
});
test('database/key/read failures are not downgraded to plaintext or an empty successful vault',async()=>{
  const e=setup();e.failOpen=true;await assert.rejects(e.repo.list(),{code:'STORAGE'});
  assert.equal(e.configs.length,1);assert.equal(e.configs[0].encrypt,true);
  e.failOpen=false;e.failRead=true;await assert.rejects(e.repo.list(),{code:'STORAGE'});
  assert.ok(e.sql.every(x=>!/(DROP|DELETE|REPLACE)/.test(x)));
});
test('malformed stored payload is rejected and result sets are always closed',async()=>{
  const e=setup();await e.repo.add(draft(e.a));e.rows[0].payload='{"secret":"broken"}';
  const before=e.closedResults;await assert.rejects(e.repo.list(),{code:'STORAGE'});assert.equal(e.closedResults,before+1);
  assert.equal(e.rows.length,1);
});
test('unknown schema version fails closed rather than dropping/recreating user data',async()=>{
  const e=setup();e.version=99;await assert.rejects(e.repo.list(),{code:'STORAGE'});assert.equal(e.sql.length,0);
});
test('locked sessions cannot open/read/write the database',async()=>{
  const e=setup();e.a.lockAppSession();await assert.rejects(e.repo.add(draft(e.a)),{code:'LOCKED'});
  assert.equal(e.configs.length,0);
});
test('queued write rechecks authentication rather than using an old unlocked UI flag',async()=>{
  const e=setup();e.waitInsert=deferred();
  const first=e.repo.add(draft(e.a));await new Promise(resolve=>setImmediate(resolve));
  const queued=e.repo.add(draft(e.a,{period:60}));e.a.lockAppSession();e.waitInsert.resolve();await first;
  await assert.rejects(queued,{code:'LOCKED'});assert.equal(e.rows.length,1);
});
test('all SQL uses bound values; user labels never become executable query text',async()=>{
  const e=setup();const text="'; DROP TABLE otp_accounts; --";await e.repo.add(draft(e.a,{issuer:text}));
  assert.ok(e.sql.every(sql=>!sql.includes(text)));assert.equal((await e.repo.list())[0].issuer,text);
});
test('native error details are sanitized by the repository boundary',async()=>{
  const e=setup();e.failWrite=true;await assert.rejects(e.repo.add(draft(e.a)),error=>error.code==='STORAGE'&&!error.message.includes('GEZDG'));
});
