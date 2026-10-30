import {test} from 'node:test';
import assert from 'node:assert/strict';
import worker, {feedback, diagnosticReport} from './worker.mjs';

const id = 'bda252ca-b416-4e3d-b29b-7e3af234a03e';
const state = {batteryPercent:null, power:'0', requested:false, stopping:false, pipActive:false};
const report = {schemaVersion:1, generatedAt:'2026-10-30T00:00:00Z', appVersion:'0.4.0', build:'6', hardware:'iPhone18,3', osVersion:'27.0', lowPowerMode:false, thermalState:0, state, events:[]};
const payload = {id, message:'复现步骤：插电开启后关闭画中画。', email:'', consent:true, diagnostics:report};
function env() {
  const rows = new Map();
  return { rows, ASSETS:{fetch:()=>new Response('page')}, FEEDBACK_LIMITER:{limit:async()=>({success:true})}, DB:{prepare(sql){return {bind(...values){this.values=values;return this}, async first(){return rows.get(this.values[0])??null},async all(){return {results:[]}},async run(){if(sql.startsWith('INSERT')) { if(!rows.has(this.values[0])) rows.set(this.values[0], {digest:this.values[2], payload:this.values[3]}); } else if(sql.includes('created_at')) rows.clear();else rows.delete(this.values[0]);return {success:true}}}}}};
}
function request(path='/api/feedback', body=payload, headers={}) { return new Request('https://auv.macseek.cc'+path, {method:'POST', headers:{'Content-Type':'application/json',...headers}, body:JSON.stringify(body)}); }
test('allowlist drops identifiers and rejects malformed or oversized reports',()=>{
  const result=diagnosticReport({...report,UDID:'secret',events:[{time:report.generatedAt,event:'pip_started',state,deviceName:'private'}]});
  assert.equal(result.UDID,undefined); assert.equal(result.events[0].deviceName,undefined);
  assert.throws(()=>diagnosticReport({...report,events:Array(201).fill({})}));
  assert.throws(()=>feedback({...payload,consent:false}));
  assert.throws(()=>feedback({...payload,email:'not-an-email'}));
  assert.throws(()=>feedback({...payload,message:'x'.repeat(4001)}));
  assert.throws(()=>feedback({...payload,website:'bot'}));
});
test('receipt, idempotent retry, conflict, deletion and no public reads',async()=>{
  const e=env(); let response=await worker.fetch(request(),e); assert.equal(response.status,201); assert.equal((await response.json()).id,id);
  assert.equal((await worker.fetch(request(),e)).status,201); assert.equal(e.rows.size,1);
  assert.equal((await worker.fetch(request('/api/feedback',{...payload,message:'完全不同的问题描述和操作步骤'}),e)).status,409);
  assert.equal((await worker.fetch(new Request('https://auv.macseek.cc/api/feedback'),e)).status,404);
  assert.equal((await worker.fetch(request('/api/feedback/delete',{id}),e)).status,200); assert.equal(e.rows.size,0);
});
test('cross-origin, rate limit, oversized body and unavailable storage fail closed',async()=>{
  const e=env(); assert.equal((await worker.fetch(request('/api/feedback',payload, {Origin:'https://attacker.test'}),e)).status,403);
  assert.equal((await worker.fetch(request('/api/feedback',{...payload,message:'x'.repeat(100000)}),e)).status,400);
  e.FEEDBACK_LIMITER.limit=async()=>({success:false}); assert.equal((await worker.fetch(request(),e)).status,429);
  e.FEEDBACK_LIMITER.limit=async()=>({success:true});e.DB.prepare=()=>{throw new Error('storage unavailable')};assert.equal((await worker.fetch(request(),e)).status,503);
});
test('scheduled cleanup uses the 30-day cutoff',async()=>{
  let cutoff;const e={DB:{prepare(sql){assert.match(sql,/created_at <=/);return {bind(value){cutoff=value;return this},run:async()=>({success:true})}}}};
  const before=Date.now()-30*86400000; await worker.scheduled({},e); assert.ok(cutoff>=before && cutoff<=Date.now()-30*86400000);
});
