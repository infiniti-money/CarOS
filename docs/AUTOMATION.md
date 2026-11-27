# CarOS automation
- AI hourly: inspect current state, fix or develop one meaningful task, do not alter an in-flight head just to restart CI. Merge only verified PRs using the exact head SHA and current base/merge tree. Do not bypass required checks.
- GitHub CI Monitor: every 15 minutes at UTC minutes 7, 22, 37, 52, after this workflow is on the default branch. Read-only audit of main and all open PRs, including job conclusions and PR base association. One active monitor via concurrency. It does not initiate duplicate Android/iOS builds, rerun failed jobs, or merge.
- Existing verify.yml builds Android/iOS on pushes to main and PR changes. Monitor success is not a green build; examine its summary and the Verify Infiniti CarOS jobs verify and ios.
- For repository-level enforcement, configure a main branch protection rule or ruleset requiring PRs, up-to-date branches and the verify and ios status checks, without bypass for routine automation. This is an administrator setting, not enforced by this monitor.
- Scheduled workflows may start late and GitHub may disable schedules on inactive public repositories. Device testing and signed releases are separate.
