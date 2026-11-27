// Read-only CI audit; this workflow never merges or changes repository state.
module.exports = async ({github, context, core}) => {
  const repo = context.repo;
  const main = (await github.rest.repos.getBranch({...repo, branch: 'main'})).data;
  const pulls = await github.paginate(github.rest.pulls.list, {...repo, state: 'open', per_page: 100});
  const targets = [{label: 'main', sha: main.commit.sha, event: 'push'}];
  for (const pr of pulls) {
    targets.push({label: '#' + pr.number + ' (' + pr.head.ref + ' -> ' + pr.base.ref + ')',
      sha: pr.head.sha, event: 'pull_request', number: pr.number, base: pr.base.sha});
  }
  const rows = [[{data:'Target',header:true},{data:'Commit',header:true},{data:'Verify',header:true},{data:'iOS',header:true},{data:'CI / base',header:true}]];
  for (const target of targets) {
    const {data} = await github.rest.actions.listWorkflowRuns({
      ...repo, workflow_id:'verify.yml', head_sha:target.sha, event:target.event, per_page:30,
    });
    const candidates = data.workflow_runs.filter(run => target.number == null ||
      (run.pull_requests || []).some(pr => pr.number === target.number));
    // If the API omits PR association, report unknown rather than guessing.
    const run = candidates[0];
    let verify = 'unknown', ios = 'unknown', status = 'missing / association unknown';
    if (run) {
      const jobs = await github.paginate(github.rest.actions.listJobsForWorkflowRun,
        {...repo, run_id:run.id, filter:'latest', per_page:100});
      const state = name => {
        const matches = jobs.filter(job => job.name === name);
        return matches.length === 1 ? (matches[0].conclusion || matches[0].status) : 'unknown';
      };
      verify = state('verify');
      ios = state('ios');
      const baseMatches = target.number == null || (run.pull_requests || []).some(
        pr => pr.number === target.number && pr.base.sha === target.base);
      status = (run.conclusion || run.status) + (baseMatches ? '' : ' / base unverified');
      if (run.conclusion === 'success' && (verify !== 'success' || ios !== 'success' || !baseMatches)) {
        status = 'not eligible / checks or base unverified';
      }
      status += ' [run ' + run.id + ']';
    }
    if (verify === 'failure' || ios === 'failure') core.warning(target.label + ': CI failure');
    rows.push([target.label, target.sha.slice(0,12), verify, ios, status]);
  }
  await core.summary.addHeading('CarOS CI audit — read only')
    .addTable(rows)
    .addRaw('Audit success means status collection succeeded, not that application CI passed. No builds, reruns or merges are initiated by this monitor. Review the exact PR head, base and required checks before merging.\n')
    .write();
};
