const {test}=require('node:test');
const assert=require('node:assert/strict');
const audit=require('./ci_monitor.cjs');
const {isHostPath}=audit;
const required={
  'verify.yml':['verify','ios'],
  'carplay-dependency.yml':['Dart analysis and tests','Android example release build','iOS example build'],
  'car-host.yml':['android','ios'],
};
async function runAudit({base='base-new',associatedBase='base-new',associated=true,
    paths=['lib/main.dart'],missing='',failed='',missingJob='',fileError=false,wrongHead=false}={}) {
  let rows;
  const warnings=[];
  const calls=[];
  const summary={addHeading(){return this;},addTable(value){rows=value;return this;},addRaw(){return this;},async write(){}};
  const pulls=[{number:7,head:{ref:'feature',sha:'head-sha'},base:{ref:'main',sha:base}}];
  const workflows=Object.keys(required);
  const rest={
    repos:{getBranch:async()=>({data:{commit:{sha:'main-sha'}}})},
    pulls:{list:async()=>pulls,listFiles:async()=>{
      if(fileError) throw Error('unavailable');
      return paths.map(path=>typeof path==='string'?{filename:path}:path);
    }},
    actions:{
      listWorkflowRuns:async({head_sha,workflow_id})=>{
        calls.push(workflow_id);
        if(head_sha!=='head-sha'||workflow_id===missing) return {data:{workflow_runs:[]}};
        return {data:{workflow_runs:[{id:workflows.indexOf(workflow_id)+1,head_sha:wrongHead?'other':head_sha,
          conclusion:workflow_id===failed?'failure':'success',status:'completed',
          pull_requests:associated?[{number:7,base:{sha:associatedBase}}]:[]}]}};
      },
      listJobsForWorkflowRun:async({run_id})=>{
        const workflow=workflows[run_id-1];
        return required[workflow].filter(name=>name!==missingJob).map((name,i)=>({name,
          conclusion:workflow===failed&&i===0?'failure':'success'}));
      },
    },
  };
  await audit({github:{rest,paginate:async(fn,args)=>fn(args)},context:{repo:{owner:'example',repo:'CarOS'}},core:{summary,warning:value=>warnings.push(value)}});
  return {row:rows[2],warnings,calls};
}
test('current base and all required app/dependency jobs report success',async()=>{
  const {row}=await runAudit();
  assert.equal(row[2],'success');assert.equal(row[3],'success');
  assert.match(row[4],/^success/);assert.match(row[5],/^success/);
  assert.match(row[7],/^checks reported success/);
});
test('stale base cannot qualify',async()=>{
  const {row}=await runAudit({associatedBase:'old'});
  assert.match(row[4],/not eligible/);assert.equal(row[7],'not eligible');
});
test('failed dependency is surfaced even if app passes',async()=>{
  const {row,warnings}=await runAudit({failed:'carplay-dependency.yml'});
  assert.match(row[4],/^success/);assert.match(row[5],/^failure/);
  assert.equal(row[7],'not eligible');assert.equal(warnings.length,1);
});
test('missing PR association or wrong head remains unknown',async()=>{
  for(const options of [{associated:false},{wrongHead:true}]) {
    const {row}=await runAudit(options);
    assert.equal(row[2],'unknown');assert.match(row[4],/association unknown/);
    assert.equal(row[7],'not eligible');
  }
});
test('missing dependency job cannot qualify',async()=>{
  const {row}=await runAudit({missingJob:'iOS example build'});
  assert.match(row[5],/not eligible/);assert.equal(row[7],'not eligible');
});
test('host workflow required for dependency or native path changes',async()=>{
  for(const paths of [['pubspec.yaml'],['native/car/CarAppDelegate.swift'],[{filename:'docs/old',previous_filename:'lib/car_main.dart'}]]) {
    const {row}=await runAudit({paths,missing:'car-host.yml'});
    assert.match(row[6],/missing/);assert.equal(row[7],'not eligible');
  }
  assert.equal(isHostPath('lib/main.dart'),false);
});
test('missing changed path evidence fails conservatively',async()=>{
  const {row}=await runAudit({fileError:true,missing:'car-host.yml'});
  assert.match(row[6],/missing/);assert.equal(row[7],'not eligible');
});
test('all required host jobs can pass',async()=>{
  const {row}=await runAudit({paths:['pubspec.yaml']});
  assert.match(row[6],/^success/);assert.match(row[7],/^checks reported success/);
});
