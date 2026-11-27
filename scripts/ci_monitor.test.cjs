const {test} = require('node:test');
const assert = require('node:assert/strict');
const audit = require('./ci_monitor.cjs');

async function runAudit({base='base-new', associatedBase='base-new', conclusion='success', jobs=[{name:'verify',conclusion:'success'},{name:'ios',conclusion:'success'}], associated=true}={}) {
  let rows;
  const warnings = [];
  const summary = {
    addHeading(){return this;},
    addTable(value){rows=value;return this;},
    addRaw(){return this;},
    async write(){},
  };
  const pulls = [{number:7,head:{ref:'feature',sha:'head-sha'},base:{ref:'main',sha:base}}];
  const run = {id:123,conclusion,status:'completed',pull_requests:associated?[{number:7,base:{sha:associatedBase}}]:[]};
  const rest = {
    repos:{getBranch:async()=>({data:{commit:{sha:'main-sha'}}})},
    pulls:{list:async()=>pulls},
    actions:{
      listWorkflowRuns:async({head_sha})=>({data:{workflow_runs:head_sha==='head-sha'?[run]:[]}}),
      listJobsForWorkflowRun:async()=>jobs,
    },
  };
  await audit({github:{rest,paginate:async(fn,args)=>fn(args)},context:{repo:{owner:'example',repo:'CarOS'}},core:{summary,warning:value=>warnings.push(value)}});
  return {row:rows[2],warnings};
}

test('current base and both successful jobs are reported', async()=>{
  const {row}=await runAudit();
  assert.equal(row[2],'success');
  assert.equal(row[3],'success');
  assert.match(row[4],/^success \[run/);
});
test('stale base cannot qualify even when CI passes', async()=>{
  const {row}=await runAudit({associatedBase:'old'});
  assert.match(row[4],/not eligible/);
});
test('failed required job is surfaced', async()=>{
  const {row,warnings}=await runAudit({conclusion:'failure',jobs:[{name:'verify',conclusion:'failure'},{name:'ios',conclusion:'success'}]});
  assert.equal(row[2],'failure');
  assert.equal(warnings.length,1);
});
test('missing PR association is unknown', async()=>{
  const {row}=await runAudit({associated:false});
  assert.equal(row[2],'unknown');
  assert.match(row[4],/association unknown/);
});
test('missing required job cannot qualify', async()=>{
  const {row}=await runAudit({jobs:[{name:'verify',conclusion:'success'}]});
  assert.match(row[4],/not eligible/);
});
