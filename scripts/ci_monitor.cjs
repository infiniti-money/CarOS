// Read-only CI audit. Never initiates builds, reruns, merges or writes.
const specs = {
  verify: {file:'verify.yml', jobs:['verify','ios']},
  dependency: {file:'carplay-dependency.yml', jobs:['Dart analysis and tests','Android example release build','iOS example build']},
  host: {file:'car-host.yml', jobs:['android','ios']},
};
function isHostPath(path) {
  return path.startsWith('native/car/') || [
    'lib/car_main.dart','lib/car_connection.dart','scripts/configure_car_host.py',
    'scripts/configure_ios_floor.py','pubspec.yaml','.github/workflows/car-host.yml',
  ].includes(path);
}

async function inspect({github, repo, target, spec}) {
  const {data} = await github.rest.actions.listWorkflowRuns({
    ...repo, workflow_id:spec.file, head_sha:target.sha, event:target.event, per_page:30,
  });
  const run = data.workflow_runs.find(row => row.head_sha === target.sha &&
    (target.number == null || (row.pull_requests || []).some(pr => pr.number === target.number)));
  const states = spec.jobs.map(() => 'unknown');
  if (!run) return {states, text:'missing / association unknown', eligible:false, failed:false};
  const jobs = await github.paginate(github.rest.actions.listJobsForWorkflowRun,
    {...repo, run_id:run.id, filter:'latest', per_page:100});
  for (let i=0; i<spec.jobs.length; i++) {
    const matches = jobs.filter(job => job.name === spec.jobs[i]);
    if (matches.length === 1) states[i] = matches[0].conclusion || matches[0].status || 'unknown';
  }
  const baseMatches = target.number == null || (run.pull_requests || []).some(
    pr => pr.number === target.number && pr.base?.sha === target.base);
  const eligible = run.status === 'completed' && run.conclusion === 'success' &&
    baseMatches && states.every(x => x === 'success');
  const failed = run.conclusion === 'failure' || states.includes('failure');
  const text = eligible ? 'success' :
    (run.conclusion === 'success' ? 'not eligible / checks or base unverified' :
    (run.conclusion || run.status || 'unknown') + (baseMatches ? '' : ' / base unverified'));
  return {states,text:text+' [run '+run.id+']',eligible,failed};
}

async function audit({github, context, core}) {
  const repo = context.repo;
  const main = (await github.rest.repos.getBranch({...repo, branch:'main'})).data;
  const pulls = await github.paginate(github.rest.pulls.list, {...repo,state:'open',per_page:100});
  const targets = [{label:'main',sha:main.commit.sha,event:'push',host:false}];
  for (const pr of pulls) {
    let host = true;
    try {
      const files = await github.paginate(github.rest.pulls.listFiles,
        {...repo,pull_number:pr.number,per_page:100});
      // GitHub's file API is capped at 3000. Fail conservatively if truncated.
      host = files.length >= 3000 || files.length === 0 ||
        files.some(file => isHostPath(file.filename) ||
          (typeof file.previous_filename === 'string' && isHostPath(file.previous_filename)));
    } catch (_) {
      core.warning('#'+pr.number+': changed paths unavailable; require host evidence');
    }
    targets.push({label:'#'+pr.number+' ('+pr.head.ref+' -> '+pr.base.ref+')',
      sha:pr.head.sha,event:'pull_request',number:pr.number,base:pr.base.sha,host});
  }
  const headers=['Target','Commit','Verify','iOS','App CI / base','CarPlay dependency','Car host','Audit gate'];
  const rows=[headers.map(data=>({data,header:true}))];
  for (const target of targets) {
    const primary=await inspect({github,repo,target,spec:specs.verify});
    const dependency=target.number == null ? null :
      await inspect({github,repo,target,spec:specs.dependency});
    const host=target.host ? await inspect({github,repo,target,spec:specs.host}) : null;
    const required=[primary,dependency,host].filter(Boolean);
    if (required.some(x=>x.failed)) core.warning(target.label+': CI failure');
    const gate=required.every(x=>x.eligible) ? 'checks reported success; verify merge tree' : 'not eligible';
    rows.push([target.label,target.sha.slice(0,12),...primary.states,primary.text,
      dependency?.text || 'not triggered on main push',
      host?.text || 'not required by path policy',gate]);
  }
  await core.summary.addHeading('CarOS CI audit — read only').addTable(rows)
    .addRaw('Audit success means status collection succeeded, not application CI success. Gate is informational: verify exact checkout merge tree, current base, required GitHub checks and permissions before any merge. No builds, reruns or merges initiated.\n').write();
}
module.exports=audit;
module.exports.isHostPath=isHostPath;
