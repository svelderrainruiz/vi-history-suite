# Test Plan

## Required Lightweight CI

Run these on pull requests and pushes to governed public branches:

```bash
npm ci
npm run check
npm run customization:audit
npm run traceability:audit
npm run docs:links
npm test
npm run package
npm run dod:gate
```

This hosted CI job remains the required public merge gate for `develop` and
`main`. The same required job also enforces branch governance: normal feature
work and Dependabot maintenance target `develop`, while only
`release/vX.Y.Z` and `hotfix/vX.Y.Z` branches target `main`.
A parallel `Windows Unit Tests` job runs `npm ci`, `npm run check`, and
`npm test` on `windows-latest` so platform-specific unit regressions (for
example path-separator assumptions in staging tests) fail closed in CI. It
intentionally omits packaging, governance gates, and coverage upload, which
remain in the required Ubuntu `Build, Test, Package` job, and it does not
exercise the heavier Windows/LabVIEW integration path, which stays
maintainer-dispatch.
A parallel `Integration Host (Linux)` job runs the LabVIEW-free VS Code
extension-host suite through `npm run test:integration:linux` on
`ubuntu-24.04` (the entrypoint auto-wraps in `xvfb-run`). It exercises
activation, eligibility indexing, command registration, panel render, and the
runtime-settings CLI against a real downloaded VS Code, putting a behavioral
floor under the command/activation layer (notably
`src/commands/openViHistoryCommand.ts`). The suite uses synthetic VI fixtures
and self-skips LabVIEW-path assertions, so it needs no LabVIEW, Docker, or real
compare; the heavier real-runtime compare path stays maintainer-dispatch. This
leg is behavioral coverage and does not contribute to the vitest coverage
number, which is collected only in the required `Build, Test, Package` job.
The traceability audit is part of the required hosted gate so newly added
implementation, test, workflow, and documentation surfaces remain classified
before merge, and the customization audit runs before traceability so AGENTS and
workspace customization drift fails closed.
The required job also emits `customization-audit-report.json` and uploads it
through `Customization Audit Report / custom-audit` so CI triage can classify
runtime issues, AGENTS sync drift, frontmatter drift, applyTo drift, markdown
link drift, and command-reference drift.
The `Traceability Audit` and `DoD Gate / dod` steps also retain
`traceability-audit-report.txt` and `dod-gate-report.txt`, uploaded through
`Governance Gate Reports / governance-gates`, so CI triage can inspect gate
evidence even when a required gate fails.
The `Docs Link Check / lychee` step runs `npm run docs:links`
inside the same required job so committed Markdown and bundled documentation
local links are checked before tests and packaging. Generated validation,
cache, coverage, package, release-evidence, and Vagrant evidence directories
are excluded from this documentation scan so retained run artifacts cannot
redden or green the committed documentation gate.

## Coverage Evidence And Threshold Policy

`npm test` runs Vitest with coverage enabled. The required hosted CI job retains
the machine-readable coverage outputs from that run through the
`PR Coverage Gate / coverage` step:

- `coverage/cobertura-coverage.xml`
- `coverage/coverage-summary.json`

The enforced coverage thresholds in `vitest.config.ts` are evidence-backed
baseline regression floors: 80% statements, 70% branches, 84% functions, and
80% lines. These floors were ratcheted toward the measured `develop` actuals at
v1.33.2, which measured 82.16% statements, 72.32% branches, 86.48% functions,
and 82.21% lines locally (the lower-running Ubuntu CI leg historically
trails by ~1 point); they are not a claim that the repository has complete
coverage. The two highest-risk
comparison-runtime files
(`src/reporting/comparisonRuntimeLocator.ts` and
`src/reporting/comparisonReportRuntimeExecution.ts`) additionally carry per-file
floors pinned just under their current actuals to prevent silent branch-coverage
drift on provider-selection and fail-closed paths. Raise the thresholds only in
a PR that shows new coverage evidence and updates this test plan with the new
baseline.

### Coverage Floor Policy

The global floors intentionally sit roughly two points below the measured
`develop` actuals. That gap is a cross-runner margin, not slack to be spent: the
Ubuntu CI leg measures coverage about one point below the local/Windows figure,
so a floor held ~1 point under the Ubuntu actual keeps ordinary cross-runner
variance from reddening the gate on unrelated pull requests.

Ratchet a floor only when it is durable, not merely reachable:

- Raise a floor in a PR that first adds real coverage lifting the actual, so the
  new floor still keeps ~2 points local (~1 point Ubuntu) margin. The Ubuntu
  `Build, Test, Package` leg validates the floor before merge — if a floor is
  set too high the PR reddens; lower it and repush.
- Move the floor in lockstep across its five pinned locations: `vitest.config.ts`,
  this test plan (floors plus the measured actuals), `docs/requirements/srs.md`
  (VHS-REQ-597), `docs/requirements/syrs.md`, and
  `tests/unit/requirementsDocs.test.ts`.
- Spend the coverage that unlocks a ratchet on requirement-mapped product logic.
  Do not chase coverage on excluded VS Code host bindings, network or socket
  boundary callbacks, or fixture-heavy integration paths purely to move a floor —
  that is low-value churn, and much of it is already excluded in
  `vitest.config.ts`.

The floors are a regression net, not a coverage-completeness claim. Once they sit
within ~2 points of actuals, further ratcheting buys marginal protection for
disproportionate effort; prefer targeted assurance (mutation testing, the
coverage traceability map) over percentage chasing.

## Mutation Testing (Advisory)

Run `npm run test:mutation` (Stryker, `stryker.config.mjs`) to mutation-test the
pure `src/domain` detection core. Coverage proves lines execute; mutation proves
the tests catch regressions, so surviving mutants pinpoint weak or missing
assertions behind requirement-mapped behavior. It is advisory
(`thresholds.break` is null) and never fails the build; use the surviving-mutant
report in `reports/mutation/mutation.json` to close assertion gaps. Widening the
mutate scope beyond `src/domain` and adding a scheduled run are separate
maintainer decisions.

## Coverage Traceability Map

Run `npm run coverage:map` after `npm test` to join
`coverage/coverage-summary.json`, `docs/requirements/traceability-inventory.csv`,
and `docs/requirements/rtm.csv`. The report highlights requirement-mapped files
below 50% coverage and zero-coverage supporting files tied to active
requirements so coverage-led assurance work starts with product-risk evidence
instead of percentage chasing. Use the report to seed follow-up coverage issues
and to justify future coverage threshold ratchets. Standards closeout runs this
map after `npm test` and before package validation so release-readiness evidence
captures coverage-risk backlog candidates without changing the Vitest threshold
gate semantics.

## Criterion Closure Docket

`npm run requirements:criteria` remains advisory (exit 0). It is useful for finding
acceptance criteria that lack a literal `VHS-REQ-N.M` citation in a verification
reference test, but the remaining Phase-3b backlog should not be closed by
adding citation text alone. `npm run requirements:criteria:enforce` (or the
`--enforce` flag) makes the same guard fail closed (exit 1) when any Active
criterion is not yet cited at the criterion level. Hosted CI runs this enforce
guard in the `Requirements CSV Integrity` job (the `Enforce requirement
criterion citation` step, after requirement-linkage enforcement), so criterion
citation is now gated on every pull request. As of 2026-07-13, after the LabVIEW CLI open-gate,
Definition-of-Done governance, VI Server gate, registry-fallback, container
image mismatch remediation, Linux container headless-recovery evidence,
staged-tree working-tree evidence, VI Preview lifecycle, PR evidence contract,
pull download-phase regression, pre-panel/compare-time gate separation, Docker
daemon fallback, comparison commit-body export, and test-harness boundary
branches, the baseline is 513/513 criterion-level citations with 0 uncited
criteria.

Classify each remaining uncited criterion before adding citations or proposing
enforcement:

| Bucket | Meaning | Closure action |
| --- | --- | --- |
| `exact-testable` | An existing verification-ref test, or a small focused unit test, directly proves the criterion. | Add the citation to the proving test or add the focused assertion and cite it. |
| `needs-new-behavior-test` | The criterion names a plausible regression risk, but no current test proves it. | Open a follow-up issue and add a real behavior test; do not cite until the assertion exists. |
| `manual/process` | The evidence is owned by a manual dispatch, release process, closeout packet, or external validation surface. | Name the manual or process evidence in this test plan or the RTM instead of forcing a unit-test citation. |
| `broad-regression` | The criterion says broad behavior is unchanged or no unrelated surface regressed. | Keep advisory unless it can be decomposed into concrete assertions. |
| `defer/product-decision` | The criterion depends on a UX, runtime, governance, or tooling decision. | Track the decision explicitly; do not create assertion theater. |

Current closure docket:

| Bucket | Criteria | Next action |
| --- | --- | --- |
| `exact-testable` | None currently assigned after the 513/513 refresh. | Keep available for newly classified criteria backed by concrete assertions. |
| `needs-new-behavior-test` | None currently assigned after the 513/513 refresh. | Decompose concrete assertions before citation; leave uncited if the proof would only restate policy or broad non-regression. |
| `manual/process` | None currently assigned after the 488/513 refresh. | Keep available for future closeout or release-review evidence that cannot be unit-tested. |
| `broad-regression` | None currently assigned after the 513/513 refresh. | Keep advisory unless each is decomposed into a concrete regression assertion that would fail on a real behavior change. |
| `defer/product-decision` | None currently assigned after aligning VHS-REQ-644.2 with the VHS-REQ-626 generated-report export contract. | Track future product decisions explicitly; do not create assertion theater. |

Final closure disposition for issue #1005: no uncited criteria remain. The last
test-harness boundary criteria are covered by the VHS-REQ-614 requirements-docs
guard, which pins the requirement to test-harness-only implementation refs and
keeps runtime, package, command, persisted-format, and Marketplace surfaces owned
by their dedicated requirements.

Recommended implementation order:

1. Criterion-linkage enforcement is now fail-closed in hosted CI (the
   `Enforce requirement criterion citation` step in the `Requirements CSV
   Integrity` job). The `npm run requirements:criteria:enforce` guard also fails
   closed locally; the default `npm run requirements:criteria` stays advisory.
2. Classify future uncited criteria before enforcement changes; do not add a
   citation unless a verification test demonstrates the criterion.

Do not add a `VHS-REQ-N.M` citation unless the cited verification test actually
demonstrates that criterion. When a true proof lives in a different verification
file, update SRS and RTM references together and run `npm run requirements:integrity`.
Use `node scripts/auditRequirementCriteriaInventory.js --json` to build or refresh
the docket. Criterion-linkage enforcement should wait until every remaining
criterion is either exactly proved or explicitly assigned to one of the other
buckets above.

## Critical-Path Verification Evidence

| Requirement | Test Evidence | Code Path | Test Path | Coverage / Rationale |
| --- | --- | --- | --- | --- |
| VHS-REQ-597 | TEST-597 | .github/workflows/ci.yml; vitest.config.ts | tests/unit/branchGovernanceWorkflow.test.ts; tests/unit/requirementsDocs.test.ts | Hosted CI retains coverage artifacts, enforces evidence-backed baseline thresholds at 80% statements, 70% branches, 84% functions, and 80% lines, and runs `DoD Gate / dod` (`npm run dod:gate`) after packaging. |
| VHS-REQ-016 | TEST-016 | src/commands/openViHistoryCommand.ts | tests/unit/openViHistoryCommand.test.ts | User-facing command stops cover missing URI, trust gate, ineligible file guidance, history-load failures, documentation routing, and explicit cancellation stages. |
| VHS-REQ-017 | TEST-017 | src/services/viHistoryModel.ts; src/ui/historyPanel.ts | tests/unit/viHistoryModel.test.ts; tests/unit/historyPanelRendering.test.ts | History model facts cover repository/path/signature/history-window decisions and previous-hash links; the minimized panel renders a slim title and the selectable commit table (hash, date, author, subject, full body) with HTML escaping. |
| VHS-REQ-639 | TEST-639 | src/git/gitCli.ts; src/services/viHistoryModel.ts; src/ui/historyPanel.ts | tests/unit/gitCli.test.ts; tests/unit/historyPanelRendering.test.ts | Commit body (git `%b`) is captured per retained revision and rendered as a dedicated commit body column replacing the adjacent-pair column, HTML-escaped with multi-line preserved and an empty-body fallback. |
| VHS-REQ-039 | TEST-039 | src/commands/openViHistoryCommand.ts; src/extension.ts | tests/unit/historyReviewPacket.test.ts; tests/unit/openViHistoryCommand.test.ts; tests/unit/historyPanelTracker.test.ts | The factual review packet is copied through the labviewViHistory.copyReviewPacket command (trust + eligibility gated), verified through clipboard and panel action summaries. |
| VHS-REQ-133 | TEST-133 | src/ui/historyPanel.ts; src/commands/openViHistoryCommand.ts; src/reporting/comparisonReportPreflight.ts; src/reporting/comparisonReportAction.ts | tests/unit/explicitComparePairWorkflow.test.ts; tests/unit/openViHistoryCommand.test.ts; tests/unit/comparisonReportPreflight.test.ts; tests/unit/comparisonReportAction.test.ts | Explicit selected/base ordering is verified from panel selection through preflight and comparison action orchestration. |
| VHS-REQ-147 | TEST-147 | src/reporting/comparisonReportRuntimeExecution.ts; src/reporting/comparisonReportPlan.ts | tests/unit/comparisonReportRuntimeExecution.test.ts | Runtime execution stages deterministic inputs from historical blobs and preserves canonical names across container report output. |
| VHS-REQ-148 | TEST-148 | src/reporting/comparisonReportRuntimeExecution.ts; src/reporting/comparisonReportPacket.ts; src/reporting/comparisonReportExecutionPlan.ts; src/reporting/comparisonReportAction.ts | tests/unit/comparisonReportRuntimeExecution.test.ts; tests/unit/comparisonReportPacket.test.ts; tests/unit/comparisonReportAction.test.ts | Retained execution evidence covers failed runtime attempts, stale output rejection, archive creation, and packet fallback display. |
| VHS-REQ-155 | TEST-155 | src/reporting/comparisonRuntimeLocator.ts; src/reporting/comparisonRuntimeDoctor.ts; src/reporting/comparisonReportAction.ts; src/reporting/comparisonReportPacket.ts | tests/unit/comparisonRuntimeLocator.test.ts; tests/unit/comparisonRuntimeDoctor.test.ts; tests/unit/comparisonReportAction.test.ts; tests/unit/comparisonReportPacket.test.ts; tests/unit/comparisonReportRuntimeExecution.test.ts | Runtime discovery diagnostics cover host/container provider decisions and user-facing blocked-runtime summaries. |
| VHS-REQ-635 | TEST-635 | src/extension.ts; src/commands/openViHistoryCommand.ts; src/services/viHistoryModel.ts; src/services/viHistoryService.ts; src/git/gitCli.ts | tests/unit/extensionActivationLazySideEffects.test.ts; tests/unit/openViHistoryCommand.test.ts; tests/unit/viHistoryModel.test.ts; tests/unit/viHistoryService.test.ts; tests/unit/gitCli.test.ts; tests/unit/packageManifest.test.ts | Opening VI History and extension API history loading evaluate the selected file directly, keep menu visibility as a hint, preserve factual ineligibility stops, and avoid repository-wide VI indexing as a prerequisite. |
| VHS-REQ-610 | TEST-610 | src/dashboard/comparisonReportArchive.ts; src/dashboard/dashboardLatestRun.ts; src/dashboard/multiReportDashboard.ts; src/dashboard/multiReportDashboardAction.ts; src/dashboard/retainedDashboardEvidence.ts; src/scenarios/decisionRecord.ts; src/scenarios/reviewScenarioRegistry.ts; src/support/repositorySupportPolicy.ts | tests/unit/comparisonReportArchive.test.ts; tests/unit/dashboardLatestRun.test.ts; tests/unit/multiReportDashboard.test.ts; tests/unit/multiReportDashboardAction.test.ts; tests/unit/retainedDashboardEvidence.test.ts; tests/unit/reviewDecisionRecord.test.ts; tests/unit/reviewScenarioSupportPolicy.test.ts | Dashboard retained-evidence archive, latest-run, aggregate rendering, action routing, proof seeding, decision records, scenario contracts, and support-tier rules have focused unit coverage. |
| VHS-REQ-611 | TEST-611 | src/docs/bundledDocumentation.ts; src/docs/bundledDocumentationAction.ts | tests/unit/bundledDocumentation.test.ts; tests/unit/bundledDocumentationAction.test.ts | Installed documentation manifest/page loading and command routing are covered directly. |
| VHS-REQ-612 | TEST-612 | src/tooling/localRuntimeSettingsCli.ts; src/extension.ts | tests/unit/localRuntimeSettingsCli.test.ts; tests/unit/packageManifest.test.ts; tests/unit/extensionActivationLazySideEffects.test.ts; tests/integration/suite/extensionHost.test.ts | Installed runtime settings CLI command exposure, argument parsing, launcher materialization, idempotent settings refresh, malformed-config errors, validation proof output, terminal output, and missing global-storage handling are verified without changing runtime selection behavior. |
| VHS-REQ-613 | TEST-613 | scripts/mapCoverageToTraceability.js; vitest.config.ts | tests/unit/coverageMapScript.test.ts; tests/unit/requirementsDocs.test.ts | Coverage map links retained coverage evidence to RTM/inventory risk and protects evidence-backed threshold ratchets. |
| VHS-REQ-614 | TEST-614 | tests/unit/vscodeTestHarness.ts | tests/unit/vscodeTestHarness.test.ts; tests/unit/requirementsDocs.test.ts | Shared VS Code fakes support coverage-led command, webview, storage, filesystem, clipboard, progress, output, and runtime CLI tests. |
| VHS-REQ-615 | TEST-615 | package.json; .github/workflows/ci.yml; .github/workflows/marketplace-release.yml; scripts/checkDefinitionOfDone.js; scripts/auditCustomizationGovernance.js; scripts/generateCloseoutEvidence.js; scripts/runMultiStandardsAudit.js; scripts/verifyMarketplaceListing.js; .github/pull_request_template.md; docs/maintainer-operations.md; docs/requirements/srs.md; docs/requirements/rtm.csv; docs/requirements/id-index.csv; docs/requirements/README.md; docs/testing/test-plan.md; docs/requirements/traceability-inventory.csv | tests/unit/definitionOfDoneGate.test.ts; tests/unit/closeoutEvidenceScript.test.ts; tests/unit/multiStandardsAuditScript.test.ts; tests/unit/marketplaceReleaseWorkflow.test.ts; tests/unit/customizationGovernanceAuditScript.test.ts; tests/unit/requirementsDocs.test.ts; tests/unit/traceabilityAuditScript.test.ts | Definition-of-Done operating contract covers issue quality, PR evidence, hosted CI order, local gates, standards provenance, closeout evidence, traceability drift prevention, release evidence, and hosted `DoD Gate / dod` enforcement in `.github/workflows/ci.yml`. |
| VHS-REQ-616 | TEST-616 | src/extension.ts; src/tooling/runtimeAutoDetect.ts; src/tooling/runtimeSettingsSeed.ts | tests/unit/runtimeAutoDetect.test.ts; tests/unit/runtimeSettingsSeed.test.ts; tests/unit/extensionActivationLazySideEffects.test.ts; tests/unit/requirementsDocs.test.ts | Activation runs the filesystem-only runtime detector and seeds or repairs `viHistorySuite.runtimeProvider`/`labviewVersion`/`labviewBitness` so fresh installs and upgrades arrive with a working comparison provider; preserves satisfiable persisted values; reports `no-runtime-detected` without writing when nothing is found. |
| VHS-REQ-617 | TEST-617 | src/extension.ts; src/ui/runtimeAvailabilityNotice.ts; src/commands/runtimeCommands.ts | tests/unit/runtimeAvailabilityNotice.test.ts; tests/unit/runtimeCommands.test.ts; tests/unit/requirementsDocs.test.ts | Status bar item reflects detection outcome, first-run information notice fires once via globalState `vihs.firstRunNoRuntimeNoticeShown`, and `onDidChangeWindowState` re-detect is throttled by `RUNTIME_RE_DETECT_THROTTLE_MS`. Three trust-gated VS Code commands expose runtime state: `Detect Runtime Now` bypasses the throttle, `Reset First-Run Runtime Notice` requires modal confirmation to clear the globalState flag, and `Show Runtime Summary` writes a structured report to the `VI History: Runtime` output channel with a clipboard Copy action. |
| VHS-REQ-620 | TEST-620 | src/extension.ts; src/ui/runtimeAvailabilityNotice.ts; src/ui/runtimeReportPanel.ts; src/commands/openRuntimeReportPanelCommand.ts; src/commands/pickRuntimeProviderCommand.ts; src/commands/runtimeCommands.ts | tests/unit/runtimeAvailabilityNotice.test.ts; tests/unit/runtimeAvailabilityWatcher.test.ts; tests/unit/runtimeReportPanel.test.ts; tests/unit/openRuntimeReportPanelCommand.test.ts; tests/unit/pickRuntimeProviderCommand.test.ts; tests/unit/runtimeCommands.test.ts; tests/unit/requirementsDocs.test.ts | Status bar label is sourced from the persisted runtime selection when `viHistorySuite.runtimeProvider`/`labviewVersion`/`labviewBitness` are populated and the combination is satisfiable per `isPersistedSelectionSatisfiable`, otherwise the auto-detection recommendation is used (silent fallback). The watcher subscribes to `onDidChangeConfiguration` filtered to `viHistorySuite` and re-renders from the cached detection without re-probing, so a `vihs --provider …` CLI invocation or manual settings.json edit updates the label immediately. The `labviewViHistory.pickRuntimeProvider` command opens the Runtime & Report Settings panel whose runtime provider section is built from the cached detection (host installations + Docker if `cliAvailable` + Clear option) and writes selections to `ConfigurationTarget.Global`; the same panel exposes the LabVIEW container image version and the comparison-report Include controls (VHS-REQ-645/651). The `Show Runtime Summary` report appends a `Drift:` line with three states: `none`, `selection differs from recommendation`, and `selection unsatisfiable on this host; falling back to recommendation`. |
| VHS-REQ-621 | TEST-621 | src/reporting/comparisonReportRuntimeExecution.ts; src/reporting/comparisonRuntimeLocator.ts; src/reporting/comparisonRuntimeDoctor.ts; src/reporting/comparisonReportAction.ts; src/commands/openViHistoryCommand.ts | tests/unit/comparisonReportRuntimeExecution.test.ts; tests/unit/comparisonRuntimeLocator.test.ts; tests/unit/comparisonRuntimeDoctor.test.ts; tests/unit/comparisonReportAction.test.ts; tests/unit/openViHistoryCommand.test.ts; tests/unit/requirementsDocs.test.ts | Windows host preflight infers the running LabVIEW bitness from the Get-Process executable path (`\Program Files\` → x64, `\Program Files (x86)\` → x86, otherwise `unknown`) via the injectable `resolveWindowsLabviewExecutablePath` seam and retains `labviewProcessBitness`/`labviewProcessExecutablePath` on `RuntimeProcessObservation`. `comparisonRuntimeLocator.locate()` short-circuits to `blockedReason='windows-host-bitness-conflict'` when the observed bitness is known and differs from the selected bitness, ahead of `windows-host-runtime-surface-contaminated`. `classifyRuntimeFailure` rewrites a generic `command-exited-nonzero` to `'labview-host-bitness-conflict'` when the retained process-exit snapshot shows a different-bitness `LabVIEW.exe`. `comparisonRuntimeDoctor` emits a next-action that names the observed bitness (or `match the running session` when unknown) and references `viHistorySuite.labviewBitness`. The pre-launch `windows-host-bitness-conflict` and `windows-host-version-conflict` blocks (VHS-REQ-653) surface a concise close-the-running-LabVIEW + `Retry Compare` toast built from structured running-vs-selected facts (`isHostBitnessConflictBlock`/`isHostVersionConflictBlock` + `buildHostBitnessConflictMessage`/`buildHostVersionConflictMessage`), suppress the verbose provider message, and do not auto-open the blocked-evidence report (the packet is still persisted); the mid-run reclassified `labview-host-bitness-conflict` failure keeps the verbose `Pick Runtime Provider` toast. The host-native rejection reason names the bitness/version conflict instead of the false `LabVIEWCLI was not located` fallback (#530). | 
| VHS-REQ-622 | TEST-622 | scripts/runWindowsRuntimeMatrix.js; scripts/windows-runtime-matrix/Invoke-RuntimeMatrixSteadyState.ps1; scripts/windows-runtime-matrix/Close-LabviewProcesses.ps1; .github/workflows/windows-runtime-matrix.yml | tests/unit/runWindowsRuntimeMatrixScript.test.ts; tests/unit/requirementsDocs.test.ts; tests/unit/windowsRuntimeMatrixWorkflow.test.ts | Maintainer-driven Windows harness drives `vihs --validate --proof-out` against a real running LabVIEW 2026 in both steady-state bitness directions (x64-host/x86-selected and x86-host/x64-selected); asserts `runtimeBlockedReason='windows-host-bitness-conflict'` and observed `LabVIEW.exe` `ExecutablePath` bitness root match on the emitted proof JSON; aggregates per-scenario outcomes into `assurance-closeout-evidence/manual-vhs-req-621.json` under schema `vi-history-suite/runtime-matrix-evidence@v1`. Race-condition reclassification (`labview-host-bitness-conflict`) is delegated to the existing unit-test contract at `tests/unit/comparisonReportRuntimeExecution.test.ts`. The dispatch-only `windows-runtime-matrix.yml` workflow runs on `vihs-windows-labview-maintainer` self-hosted runner under a trusted-ref allow-list and uploads matrix evidence + proofs as a build artifact. The Node driver module exposes a `runRuntimeMatrix(deps)` entry whose `spawnSync`, `getCimProcesses`, `closeLabview`, `now`, and `cwd` collaborators are injectable; the default CLI binding refuses non-Windows hosts unless `VIHS_FAKE_WINDOWS=1`. |
| VHS-REQ-623 | TEST-623 | src/reporting/comparisonReportRuntimeExecution.ts; src/reporting/comparisonReportPacket.ts; src/tooling/localRuntimeSettingsCli.ts | tests/unit/comparisonReportRuntimeExecution.test.ts; tests/unit/localRuntimeSettingsCli.test.ts; tests/unit/runWindowsRuntimeMatrixScript.test.ts; tests/unit/requirementsDocs.test.ts | Windows host-native `labview-cli` runs read the `LabVIEW.ini` adjacent to the selected LabVIEW executable before launching LabVIEWCLI and block execution with `blockedReason='windows-vi-server-tcp-disabled'` when `server.tcp.enabled=False` is explicitly set, paralleling the Linux preflight from VHS-REQ-156. `WindowsLabviewTcpSettings.viServerTcpEnabled` is a tri-state field: `true` when the key is `True` or absent (Windows LabVIEW defaults VI Server TCP on), `false` only when the key is explicitly `False`, and `'unknown'` when the ini is not readable (preserves the prior implicit-enabled behavior). The block runs after `preflightLinuxHostRuntimeSurface` and before `preflightWindowsHostRuntimeSurface`. The `lvcompare` engine is exempt. No auto-mutation of `LabVIEW.ini`. The `vihs --validate` runtime-validation proof serializes the observed host VI Server port (`runtime.hostLabviewTcpPort`) and its `LabVIEW.ini` path (`runtime.hostLabviewIniPath`), recorded as explicit `null` when the runtime is not Windows host-native; the Windows runtime matrix harness `port-A` scenario (maintainer real-hardware, dispatch-only) derives its expected VI Server port from the selected install's own `LabVIEW.ini` (the same parse the product uses) rather than a hardcoded or operator-supplied constant, then asserts the admitted (`blockedReason=none`) run's proof reports `hostLabviewIniPath` equal to that selected install's ini and `hostLabviewTcpPort` equal to the port parsed from it, so the contract stays correct for whatever port the operator configures and proves the product read the selected install rather than the latest-used one. |
| VHS-REQ-001 | TEST-001 evidence granularity: file | src/domain/viMagicCore.ts; src/domain/viMagic.ts | tests/unit/viMagic.test.ts; tests/unit/viMagicWrapper.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-001; no per-requirement test exists. |
| VHS-REQ-003 | TEST-003 evidence granularity: file | src/domain/viMagicCore.ts; package.json | tests/unit/viMagic.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-003; no per-requirement test exists. |
| VHS-REQ-004 | TEST-004: stub, generic files only | package.json | none | Stub: only generic files cite VHS-REQ-004 (generic-evidence-only, see docs/testing/wiki-stub-reasons.json). |
| VHS-REQ-006 | TEST-006 evidence granularity: file | src/commands/openViHistoryCommand.ts; src/services/viHistoryModel.ts; src/services/viHistoryService.ts; src/git/gitCli.ts | tests/unit/openViHistoryCommand.test.ts; tests/unit/viHistoryModel.test.ts; tests/unit/viHistoryService.test.ts; tests/unit/gitCli.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-006; no per-requirement test exists. |
| VHS-REQ-007 | TEST-007 evidence granularity: file | src/git/gitCli.ts | tests/unit/gitCli.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-007; no per-requirement test exists. |
| VHS-REQ-008 | TEST-008 evidence granularity: file | src/git/gitCli.ts; src/services/viHistoryModel.ts | tests/unit/gitCli.test.ts; tests/unit/viHistoryModel.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-008; no per-requirement test exists. |
| VHS-REQ-010 | TEST-010 evidence granularity: file | src/domain/viFile.ts; src/domain/viMagic.ts | tests/unit/viFile.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-010; no per-requirement test exists. |
| VHS-REQ-011 | TEST-011 evidence granularity: file | src/domain/viMagic.ts | tests/unit/viMagicWrapper.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-011; no per-requirement test exists. |
| VHS-REQ-012 | TEST-012 evidence granularity: file | src/commands/openViHistoryCommand.ts; package.json | tests/unit/openViHistoryCommand.test.ts; tests/unit/extensionActivationLazySideEffects.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-012; no per-requirement test exists. |
| VHS-REQ-013 | TEST-013 evidence granularity: file | src/commands/openViHistoryCommand.ts; package.json | tests/unit/openViHistoryCommand.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-013; no per-requirement test exists. |
| VHS-REQ-040 | TEST-040 evidence granularity: file | src/ui/historyPanel.ts | tests/unit/historyReviewPacket.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-040; no per-requirement test exists. |
| VHS-REQ-061 | TEST-061 evidence granularity: file | src/services/viHistoryService.ts; src/git/gitCli.ts; src/git/gitApi.ts | tests/unit/viHistoryService.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-061; no per-requirement test exists. |
| VHS-REQ-082 | TEST-082 evidence granularity: file | package.json; src/extension.ts | tests/unit/extensionActivationLazySideEffects.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-082; no per-requirement test exists. |
| VHS-REQ-083 | TEST-083 evidence granularity: file | package.json; src/extension.ts | tests/unit/extensionActivationLazySideEffects.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-083; no per-requirement test exists. |
| VHS-REQ-084 | TEST-084: stub, generic files only | package.json | none | Stub: only generic files cite VHS-REQ-084 (generic-evidence-only, see docs/testing/wiki-stub-reasons.json). |
| VHS-REQ-127 | TEST-127 evidence granularity: file | src/reporting/comparisonReportPreflight.ts | tests/unit/comparisonReportPreflight.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-127; no per-requirement test exists. |
| VHS-REQ-128 | TEST-128 evidence granularity: file | src/reporting/comparisonReportPreflight.ts; src/domain/viMagicCore.ts | tests/unit/comparisonReportPreflight.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-128; no per-requirement test exists. |
| VHS-REQ-156 | TEST-156 evidence granularity: file | src/reporting/comparisonReportExecutionPlan.ts; src/reporting/comparisonReportRuntimeExecution.ts | tests/unit/comparisonReportExecutionPlan.test.ts; tests/unit/comparisonReportRuntimeExecution.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-156; no per-requirement test exists. |
| VHS-REQ-596 | TEST-596 evidence granularity: file | .devcontainer/devcontainer.json; README.md; INSTALL.md; FIRST-RUN.md; docs/development.md; docs/testing/test-plan.md; .github/ISSUE_TEMPLATE/first_time_onboarding_feedback.yml | tests/unit/publicDevcontainerSurface.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-596; no per-requirement test exists. |
| VHS-REQ-598 | TEST-598 evidence granularity: file | .github/workflows/windows-labview-maintainer.yml; scripts/checkMaintainerRunnerPrerequisites.js; src/tooling/integrationHostRuntime.ts; docs/maintainer-operations.md | tests/unit/windowsLabviewMaintainerWorkflow.test.ts; tests/unit/checkMaintainerRunnerPrerequisites.test.ts; tests/unit/integrationHostRuntime.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-598; no per-requirement test exists. |
| VHS-REQ-599 | TEST-599: stub, generic files only | docs/vagrant.md; vagrant/Vagrantfile; vagrant/provision/bootstrap.ps1; vagrant/provision/prepare-cold-labview.ps1; package.json | none | Stub: only generic files cite VHS-REQ-599 (generic-evidence-only, see docs/testing/wiki-stub-reasons.json). |
| VHS-REQ-600 | TEST-600 evidence granularity: file | package.json; README.md; INSTALL.md; FIRST-RUN.md; SUPPORT.md; SECURITY.md; docs/maintainer-operations.md; .github/ISSUE_TEMPLATE/first_time_onboarding_feedback.yml | tests/unit/publicDocSourceLinks.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-600; no per-requirement test exists. |
| VHS-REQ-601 | TEST-601 evidence granularity: file | docs/requirements/README.md; docs/requirements/copilot-web-issue-generation-prompt.md; docs/requirements/syrs.md; docs/requirements/srs.md; docs/requirements/rtm.csv; docs/requirements/id-index.csv; docs/requirements/traceability-inventory.csv; scripts/auditTraceabilitySteward.js; scripts/checkRequirementsCsvColumns.js; scripts/checkRequirementsIntegrity.js; scripts/generateCloseoutEvidence.js; scripts/auditRequirementVerificationLinkage.js; scripts/auditRequirementCriteriaInventory.js; scripts/verifyRequirementsHealth.js; scripts/exportRequirementsManifest.js; scripts/buildRiskLedger.js; docs/requirements/runtime-validation-ledger.json; scripts/recordRuntimeValidation.js; .github/ISSUE_TEMPLATE/requirement_target.yml | tests/unit/requirementsCsvColumns.test.ts; tests/unit/requirementsIntegrity.test.ts; tests/unit/requirementVerificationLinkage.test.ts; tests/unit/requirementCriteriaInventory.test.ts; tests/unit/requirementsManifestExport.test.ts; tests/unit/schemaEnvelopeLib.test.ts; tests/unit/outputContractLib.test.ts; tests/unit/recordRuntimeValidationScript.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-601; no per-requirement test exists. Evidence cap: 4 further cited file(s) are listed in docs/testing/wiki-stub-reasons.json. |
| VHS-REQ-602 | TEST-602 evidence granularity: file | .github/dependabot.yml; .github/workflows/codeql.yml; package.json; scripts/auditPackagedRuntimeSurface.js | tests/unit/securityMaintenanceWorkflows.test.ts; tests/unit/packageRuntimeSurfaceAudit.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-602; no per-requirement test exists. |
| VHS-REQ-607 | TEST-607: stub, generic files only | .github/ISSUE_TEMPLATE/bug_report.yml; .github/ISSUE_TEMPLATE/first_time_onboarding_feedback.yml | none | Stub: only generic files cite VHS-REQ-607 (generic-evidence-only, see docs/testing/wiki-stub-reasons.json). |
| VHS-REQ-608 | TEST-608 evidence granularity: file | .github/workflows/package-test-vsix.yml; docs/maintainer-operations.md; docs/testing/test-plan.md | tests/unit/packageTestVsixWorkflow.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-608; no per-requirement test exists. |
| VHS-REQ-609 | TEST-609 evidence granularity: file | .github/workflows/ci.yml; .github/workflows/marketplace-release.yml; .github/dependabot.yml; docs/maintainer-operations.md; docs/cm/cm-plan.md; docs/testing/test-plan.md; scripts/verifyMarketplaceListing.js | tests/unit/branchGovernanceWorkflow.test.ts; tests/unit/marketplaceReleaseWorkflow.test.ts; tests/unit/marketplaceListingVerification.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-609; no per-requirement test exists. |
| VHS-REQ-619 | TEST-619 evidence granularity: file | src/extension.ts; src/tooling/gitPrerequisiteDetect.ts; src/ui/gitPrerequisiteNotice.ts | tests/unit/gitPrerequisiteDetect.test.ts; tests/unit/gitPrerequisiteNotice.test.ts; tests/unit/extensionActivationLazySideEffects.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-619; no per-requirement test exists. |
| VHS-REQ-624 | TEST-624 evidence granularity: file | src/reporting/comparisonReportPlan.ts; src/reporting/comparisonReportRuntimeExecution.ts; src/reporting/comparisonReportPacket.ts | tests/unit/comparisonReportRuntimeExecution.test.ts; tests/unit/comparisonReportPacket.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-624; no per-requirement test exists. |
| VHS-REQ-625 | TEST-625 evidence granularity: file | src/reporting/comparisonReportPreflight.ts; src/reporting/comparisonReportPacket.ts | tests/unit/comparisonReportPreflight.test.ts; tests/unit/comparisonReportPacket.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-625; no per-requirement test exists. |
| VHS-REQ-626 | TEST-626 evidence granularity: file | package.json; src/reporting/comparisonReportExport.ts; src/reporting/comparisonReportAction.ts; src/reporting/comparisonReportContextMarkup.ts; src/extension.ts | tests/unit/comparisonReportExport.test.ts; tests/unit/comparisonReportAction.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-626; no per-requirement test exists. |
| VHS-REQ-627 | TEST-627 evidence granularity: file | src/extension.ts; src/ui/runtimeAvailabilityNotice.ts | tests/unit/extensionActivationLazySideEffects.test.ts; tests/unit/runtimeAvailabilityNotice.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-627; no per-requirement test exists. |
| VHS-REQ-628 | TEST-628 evidence granularity: file | src/reporting/comparisonRuntimeDoctor.ts | tests/unit/comparisonRuntimeDoctor.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-628; no per-requirement test exists. |
| VHS-REQ-629 | TEST-629 evidence granularity: file | src/extension.ts; src/ui/runtimeAvailabilityNotice.ts | tests/unit/runtimeAvailabilityNotice.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-629; no per-requirement test exists. |
| VHS-REQ-630 | TEST-630 evidence granularity: file | src/reporting/comparisonReportRuntimeExecution.ts; src/reporting/comparisonRuntimeDoctor.ts | tests/unit/comparisonReportRuntimeExecution.test.ts; tests/unit/comparisonRuntimeDoctor.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-630; no per-requirement test exists. |
| VHS-REQ-631 | TEST-631 evidence granularity: file | src/extension.ts; src/ui/runtimeAvailabilityNotice.ts | tests/unit/extensionActivationLazySideEffects.test.ts; tests/unit/runtimeAvailabilityNotice.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-631; no per-requirement test exists. |
| VHS-REQ-632 | TEST-632 evidence granularity: file | src/tooling/labviewInstallCatalog.ts; src/tooling/runtimeAutoDetect.ts; src/reporting/comparisonRuntimeLocator.ts | tests/unit/labviewInstallCatalog.test.ts; tests/unit/runtimeAutoDetect.test.ts; tests/unit/comparisonRuntimeLocator.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-632; no per-requirement test exists. |
| VHS-REQ-633 | TEST-633 evidence granularity: file | package.json; src/reporting/comparisonReportAction.ts; src/ui/runtimeAvailabilityNotice.ts; src/extension.ts | tests/unit/comparisonReportAction.test.ts; tests/unit/runtimeAvailabilityNotice.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-633; no per-requirement test exists. |
| VHS-REQ-634 | TEST-634 evidence granularity: file | src/reporting/comparisonRuntimeLocator.ts; src/ui/runtimeAvailabilityNotice.ts; src/extension.ts | tests/unit/comparisonRuntimeLocator.test.ts; tests/unit/extensionActivationLazySideEffects.test.ts; tests/unit/runtimeAvailabilityNotice.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-634; no per-requirement test exists. |
| VHS-REQ-636 | TEST-636 evidence granularity: file | src/extension.ts; src/ui/runtimeAvailabilityNotice.ts; src/reporting/comparisonReportRuntimeExecution.ts | tests/unit/runtimeAvailabilityNotice.test.ts; tests/unit/comparisonReportRuntimeExecution.test.ts; tests/unit/extensionActivationLazySideEffects.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-636; no per-requirement test exists. |
| VHS-REQ-637 | TEST-637 evidence granularity: file | src/extension.ts; src/ui/runtimeAvailabilityNotice.ts; src/reporting/comparisonReportRuntimeExecution.ts | tests/unit/runtimeAvailabilityNotice.test.ts; tests/unit/comparisonReportRuntimeExecution.test.ts; tests/unit/extensionActivationLazySideEffects.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-637; no per-requirement test exists. |
| VHS-REQ-638 | TEST-638 evidence granularity: file | src/reporting/comparisonReportAction.ts; src/reporting/comparisonReportExport.ts; src/extension.ts; package.json | tests/unit/comparisonReportAction.test.ts; tests/unit/extensionActivationLazySideEffects.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-638; no per-requirement test exists. |
| VHS-REQ-640 | TEST-640 evidence granularity: file | src/reporting/comparisonReportExecutionPlan.ts; src/reporting/comparisonReportPlan.ts; src/reporting/comparisonReportAction.ts | tests/unit/comparisonReportExecutionPlan.test.ts; tests/unit/comparisonReportAction.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-640; no per-requirement test exists. |
| VHS-REQ-641 | TEST-641 evidence granularity: file | src/git/gitCli.ts; src/services/viHistoryModel.ts; src/reporting/comparisonReportPreflight.ts; src/reporting/comparisonReportRuntimeExecution.ts; src/reporting/comparisonReportAction.ts; src/reporting/comparisonReportPacket.ts; src/commands/openViHistoryCommand.ts; src/ui/historyPanel.ts; src/dashboard/worktreeSnapshotIndex.ts; src/dashboard/comparisonReportArchive.ts; src/dashboard/multiReportDashboard.ts; package.json | tests/unit/viHistoryModel.test.ts; tests/unit/worktreeSnapshotIndex.test.ts; tests/unit/comparisonReportArchive.test.ts; tests/unit/multiReportDashboard.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-641; no per-requirement test exists. Evidence cap: 5 further cited file(s) are listed in docs/testing/wiki-stub-reasons.json. |
| VHS-REQ-642 | TEST-642 evidence granularity: file | src/reporting/comparisonReportAction.ts; src/commands/openViHistoryCommand.ts; src/ui/historyPanelTracker.ts | tests/unit/comparisonReportAction.test.ts; tests/unit/openViHistoryCommand.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-642; no per-requirement test exists. |
| VHS-REQ-643 | TEST-643 evidence granularity: file | src/reporting/comparisonReportAction.ts; src/commands/openViHistoryCommand.ts; src/ui/historyPanelTracker.ts | tests/unit/comparisonReportAction.test.ts; tests/unit/openViHistoryCommand.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-643; no per-requirement test exists. |
| VHS-REQ-644 | TEST-644 evidence granularity: file | src/reporting/comparisonReportPacket.ts; src/reporting/comparisonReportAction.ts; src/reporting/comparisonReportExport.ts | tests/unit/comparisonReportPacket.test.ts; tests/unit/comparisonReportAction.test.ts; tests/unit/comparisonReportExport.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-644; no per-requirement test exists. |
| VHS-REQ-645 | TEST-645 evidence granularity: file | package.json; src/reporting/comparisonReportPlan.ts; src/reporting/comparisonReportExecutionPlan.ts; src/reporting/comparisonReportRuntimeExecution.ts; src/reporting/comparisonReportAction.ts; src/ui/runtimeReportPanel.ts; src/commands/openRuntimeReportPanelCommand.ts | tests/unit/comparisonReportExecutionPlan.test.ts; tests/unit/runtimeReportPanel.test.ts; tests/unit/comparisonReportOptionSelection.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-645; no per-requirement test exists. Evidence cap: 2 further cited file(s) are listed in docs/testing/wiki-stub-reasons.json. |
| VHS-REQ-646 | TEST-646 evidence granularity: file | src/tooling/containerImageCatalog.ts | tests/unit/containerImageCatalog.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-646; no per-requirement test exists. |
| VHS-REQ-647 | TEST-647 evidence granularity: file | src/tooling/containerImageCatalog.ts; src/commands/pickContainerImageVersionCommand.ts | tests/unit/containerImageCatalog.test.ts; tests/unit/pickContainerImageVersionCommand.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-647; no per-requirement test exists. |
| VHS-REQ-648 | TEST-648 evidence granularity: file | src/tooling/containerImageCatalog.ts; src/commands/pickContainerImageVersionCommand.ts | tests/unit/containerImageCatalog.test.ts; tests/unit/pickContainerImageVersionCommand.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-648; no per-requirement test exists. |
| VHS-REQ-649 | TEST-649 evidence granularity: file | package.json; src/commands/pickContainerImageVersionCommand.ts; src/commands/openRuntimeReportPanelCommand.ts; src/extension.ts | tests/unit/openRuntimeReportPanelCommand.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-649; no per-requirement test exists. Evidence cap: 1 further cited file(s) are listed in docs/testing/wiki-stub-reasons.json. |
| VHS-REQ-650 | TEST-650 evidence granularity: file | src/reporting/comparisonRuntimeLocator.ts; src/reporting/comparisonRuntimeDoctor.ts; src/reporting/comparisonReportAction.ts; src/commands/openViHistoryCommand.ts; src/commands/pickContainerImageVersionCommand.ts | tests/unit/comparisonRuntimeLocator.test.ts; tests/unit/comparisonRuntimeDoctor.test.ts; tests/unit/comparisonReportAction.test.ts; tests/unit/openViHistoryCommand.test.ts; tests/unit/pickContainerImageVersionCommand.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-650; no per-requirement test exists. |
| VHS-REQ-651 | TEST-651 evidence granularity: file | src/commands/openRuntimeReportPanelCommand.ts; src/ui/runtimeReportPanel.ts; src/commands/pickContainerImageVersionCommand.ts; src/extension.ts; package.json | tests/unit/openRuntimeReportPanelCommand.test.ts; tests/unit/extensionActivationLazySideEffects.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-651; no per-requirement test exists. |
| VHS-REQ-652 | TEST-652 evidence granularity: file | .github/workflows/linux-labview-maintainer.yml; scripts/checkMaintainerRunnerPrerequisites.js; docs/maintainer-operations.md | tests/unit/linuxLabviewMaintainerWorkflow.test.ts; tests/unit/checkMaintainerRunnerPrerequisites.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-652; no per-requirement test exists. |
| VHS-REQ-653 | TEST-653 evidence granularity: file | src/reporting/comparisonRuntimeLocator.ts; src/reporting/comparisonRuntimeDoctor.ts; src/reporting/comparisonReportAction.ts; src/commands/openViHistoryCommand.ts; scripts/runWindowsRuntimeMatrix.js; scripts/windows-runtime-matrix/Invoke-RuntimeMatrixSteadyState.ps1; .github/workflows/windows-runtime-matrix.yml | tests/unit/comparisonRuntimeLocator.test.ts; tests/unit/comparisonRuntimeDoctor.test.ts; tests/unit/comparisonReportAction.test.ts; tests/unit/openViHistoryCommand.test.ts; tests/unit/runWindowsRuntimeMatrixScript.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-653; no per-requirement test exists. |
| VHS-REQ-654 | TEST-654 evidence granularity: file | src/tooling/dockerImagePullProgress.ts; src/reporting/comparisonRuntimeLocator.ts | tests/unit/dockerImagePullProgress.test.ts; tests/unit/comparisonRuntimeLocator.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-654; no per-requirement test exists. |
| VHS-REQ-655 | TEST-655 evidence granularity: file | src/tooling/dockerImageDownloadSize.ts; src/tooling/dockerImagePullProgress.ts | tests/unit/dockerImageDownloadSize.test.ts; tests/unit/dockerImagePullProgress.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-655; no per-requirement test exists. |
| VHS-REQ-656 | TEST-656 evidence granularity: file | src/tooling/dockerImagePullProgress.ts; src/reporting/comparisonRuntimeLocator.ts | tests/unit/dockerImagePullProgress.test.ts; tests/unit/comparisonRuntimeLocator.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-656; no per-requirement test exists. |
| VHS-REQ-657 | TEST-657 evidence granularity: file | src/tooling/containerImageCatalog.ts; src/reporting/comparisonReportRuntimeExecution.ts; src/reporting/comparisonRuntimeLocator.ts; src/reporting/comparisonRuntimeDoctor.ts; src/commands/pickRuntimeProviderCommand.ts; src/tooling/runtimeSettingsSeed.ts; src/ui/runtimeAvailabilityNotice.ts; src/commands/openRuntimeReportPanelCommand.ts; src/ui/runtimeReportPanel.ts | tests/unit/containerImageCatalog.test.ts; tests/unit/runtimeSettingsSeed.test.ts; tests/unit/pickRuntimeProviderCommand.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-657; no per-requirement test exists. Evidence cap: 5 further cited file(s) are listed in docs/testing/wiki-stub-reasons.json. |
| VHS-REQ-658 | TEST-658 evidence granularity: file | src/reporting/comparisonReportRuntimeExecution.ts; src/reporting/comparisonReportAction.ts; src/commands/openViHistoryCommand.ts; src/reporting/comparisonRuntimeDoctor.ts | tests/unit/comparisonReportRuntimeExecution.test.ts; tests/unit/comparisonReportAction.test.ts; tests/unit/openViHistoryCommand.test.ts; tests/unit/comparisonRuntimeDoctor.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-658; no per-requirement test exists. |
| VHS-REQ-659 | TEST-659 evidence granularity: file | package.json; src/reporting/viPreview/viPreviewCommandPlan.ts; src/reporting/viPreview/viPreviewCacheInspection.ts; src/reporting/viPreview/viPreviewExecution.ts; src/reporting/viPreview/viPreviewFileRender.ts; src/reporting/viPreview/viPreviewStaging.ts; src/reporting/viPreview/viPreviewCache.ts; src/reporting/viPreview/viPreviewCacheWarmer.ts; src/reporting/viPreview/viPreviewRuntimeAdapter.ts; src/reporting/viPreview/viPreviewWebview.ts; src/reporting/viPreview/viPreviewRenderSource.ts; src/reporting/viPreview/viPreviewFramesModel.ts; src/reporting/viPreview/viPreviewFramesViewer.ts; src/reporting/viPreview/viPreviewFlatFrames.ts; src/reporting/viPreview/viPreviewRenderMode.ts; src/ui/viPreviewEditor.ts; src/ui/viPreviewRenderHost.ts; src/ui/viPreviewCacheWarmerService.ts; src/ui/viPreviewContainerSession.ts; src/ui/viPreviewSessionManager.ts; src/git/revisionViTree.ts; src/reporting/viPreview/viPreviewSessionRuntime.ts; src/reporting/viPreview/viPreviewVerification.ts; src/tooling/viPreviewVerifyCli.ts; src/tooling/viPreviewDiagnostics.ts; resources/labview-cli-operations/PrintToSingleFileHtml/PrintToSingleFileHtml.lvclass | tests/unit/viPreviewEditor.test.ts; tests/unit/viPreviewCache.test.ts; tests/unit/viPreviewRuntimeAdapter.test.ts; tests/unit/viPreviewWebview.test.ts; tests/unit/viPreviewRenderSource.test.ts; tests/unit/viPreviewFramesViewer.test.ts; tests/unit/viPreviewSessionManager.test.ts; tests/unit/viPreviewSessionRuntime.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-659; no per-requirement test exists. Evidence cap: 12 further cited file(s) are listed in docs/testing/wiki-stub-reasons.json. |
| VHS-REQ-660 | TEST-660 evidence granularity: file | src/semantic/viSemanticNarrativeCache.ts; src/ui/viSemanticDecorationProvider.ts; src/extension.ts | tests/unit/viSemanticNarrativeCache.test.ts; tests/unit/viSemanticDecorationProvider.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-660; no per-requirement test exists. |
| VHS-REQ-661 | TEST-661 evidence granularity: file | .github/workflows/vi-semantic-pr-review.yml; .github/workflows/vi-semantic-pr-review-callable.yml; docs/consumer-workflows/vi-semantic-review-on-pr.yml; src/cli/runViSemanticPrReview.ts; src/semantic/viSemanticPrReview.ts; src/semantic/stickyPrComment.ts; src/semantic/viSemanticReviewMarkdown.ts; src/semantic/viSemanticNoChangeDetection.ts; src/semantic/viComparisonReportImages.ts; src/semantic/viReviewCommitStatus.ts | tests/unit/viSemanticPrReviewWorkflow.test.ts; tests/unit/viSemanticReviewOnPrTemplate.test.ts; tests/unit/viSemanticNoChangeDetection.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-661; no per-requirement test exists. Evidence cap: 1 further cited file(s) are listed in docs/testing/wiki-stub-reasons.json. |
| VHS-REQ-662 | TEST-662 evidence granularity: file | src/semantic/viSemanticModel.ts; src/semantic/viSemanticSchemas.ts; src/semantic/viSemanticComparisonMcp.ts; src/semantic/compareViRevisions.ts; src/semantic/viComparisonModelCache.ts; src/semantic/viSemanticHistory.ts; src/semantic/viRepositoryIndex.ts; src/mcp/viSemanticMcpServerProvider.ts; src/mcp/viSemanticMcpServerDeps.ts | tests/unit/viSemanticModel.test.ts; tests/unit/viSemanticSchemas.test.ts; tests/unit/viComparisonModelCache.test.ts; tests/unit/viSemanticHistory.test.ts; tests/unit/viRepositoryIndex.test.ts; tests/unit/viSemanticMcpServerProvider.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-662; no per-requirement test exists. Evidence cap: 3 further cited file(s) are listed in docs/testing/wiki-stub-reasons.json. |
| VHS-REQ-663 | TEST-663 evidence granularity: file | src/reporting/comparisonReportRuntimeExecution.ts | tests/unit/comparisonReportRuntimeExecution.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-663; no per-requirement test exists. |
| VHS-REQ-664 | TEST-664 evidence granularity: file | src/reporting/viPreview/viChangeWarmScheduler.ts; src/ui/viChangeWarmerService.ts; src/extension.ts; package.json | tests/unit/viChangeWarmScheduler.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-664; no per-requirement test exists. |
| VHS-REQ-665 | TEST-665 evidence granularity: file | src/reporting/comparisonReportRuntimeExecution.ts | tests/unit/comparisonReportRuntimeExecution.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-665; no per-requirement test exists. |
| VHS-REQ-666 | TEST-666 evidence granularity: file | scripts/checkReleaseReadiness.js; .github/workflows/marketplace-release.yml; docs/requirements/runtime-validation-ledger.json; vagrant/box-manifest.json; package.json; docs/vagrant.md; docs/maintainer-operations.md | tests/unit/marketplaceReleaseWorkflow.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-666; no per-requirement test exists. Evidence cap: 1 further cited file(s) are listed in docs/testing/wiki-stub-reasons.json. |
| VHS-REQ-667 | TEST-667 evidence granularity: file | docs/devtools-release.manifest.json; scripts/buildDevToolsRelease.js; scripts/verifyDevToolsRelease.js; .github/workflows/devtools-release.yml; package.json | tests/unit/buildDevToolsReleaseScript.test.ts; tests/unit/verifyDevToolsReleaseScript.test.ts; tests/unit/devToolsReleaseWorkflow.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-667; no per-requirement test exists. |
| VHS-REQ-668 | TEST-668 evidence granularity: file | scripts/buildSupplyChainState.js; scripts/checkReleaseReadiness.js; .github/workflows/marketplace-release.yml; .github/workflows/ci.yml; package.json | tests/unit/supplyChainStateScript.test.ts; tests/unit/releaseReadinessScript.test.ts; tests/unit/marketplaceReleaseWorkflow.test.ts; tests/unit/branchGovernanceWorkflow.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-668; no per-requirement test exists. |
| VHS-REQ-669 | TEST-669 evidence granularity: file | src/reporting/runtime/localViServerAcquisitionLock.ts; src/reporting/runtime/cycleMeter.ts; src/reporting/viPreview/viPreviewExecution.ts | tests/unit/localViServerAcquisitionLock.test.ts; tests/unit/cycleMeter.test.ts; tests/unit/viPreviewExecution.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-669; no per-requirement test exists. |
| VHS-REQ-670 | TEST-670 evidence granularity: file | scripts/buildReleaseState.js; scripts/checkReleaseReadiness.js; .github/workflows/marketplace-release.yml; package.json | tests/unit/releaseStateScript.test.ts; tests/unit/releaseReadinessScript.test.ts; tests/unit/marketplaceReleaseWorkflow.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-670; no per-requirement test exists. |
| VHS-REQ-671 | TEST-671 evidence granularity: file | src/cli/runViPreviewCacheWarmer.ts; src/reporting/viPreview/viPreviewWorkspaceScan.ts; src/reporting/viPreview/viPreviewFileRender.ts; docs/consumer-workflows/codespace-preview-cache.devcontainer.json; package.json | tests/unit/viPreviewWorkspaceScan.test.ts; tests/unit/viPreviewCacheWarmerCli.test.ts; tests/unit/codespacePreviewCacheTemplate.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-671; no per-requirement test exists. |
| VHS-REQ-672 | TEST-672 evidence granularity: file | src/cli/runViPreviewCacheBundle.ts; src/reporting/viPreview/viPreviewCacheBundle.ts; package.json | tests/unit/viPreviewCacheBundle.test.ts; tests/unit/viPreviewCacheBundleCli.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-672; no per-requirement test exists. |
| VHS-REQ-673 | TEST-673 evidence granularity: file | src/cli/runViPreviewCacheExchange.ts; src/reporting/viPreview/viPreviewCacheExchange.ts; package.json | tests/unit/viPreviewCacheExchange.test.ts; tests/unit/viPreviewCacheExchangeCli.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-673; no per-requirement test exists. |
| VHS-REQ-674 | TEST-674 evidence granularity: file | .github/workflows/preview-cache-fleet-callable.yml; .github/workflows/preview-cache-fleet.yml; src/cli/runViPreviewCacheWarmer.ts; src/reporting/viPreview/viPreviewWorkspaceScan.ts | tests/unit/previewCacheFleetWorkflow.test.ts; tests/unit/viPreviewWorkspaceScan.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-674; no per-requirement test exists. |
| VHS-REQ-675 | TEST-675 evidence granularity: file | src/cli/runViPreviewCacheHealth.ts; src/reporting/viPreview/viPreviewCacheHealth.ts; package.json | tests/unit/viPreviewCacheHealth.test.ts; tests/unit/viPreviewCacheHealthCli.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-675; no per-requirement test exists. |
| VHS-REQ-676 | TEST-676 evidence granularity: file | src/support/semver.ts; scripts/lib/semver.cjs; docs/devtools-release.manifest.json; scripts/buildDevToolsRelease.js; .github/workflows/devtools-release.yml | tests/unit/semver.test.ts; tests/unit/buildDevToolsReleaseScript.test.ts; tests/unit/devToolsReleaseWorkflow.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-676; no per-requirement test exists. |
| VHS-REQ-677 | TEST-677 evidence granularity: file | src/tooling/devToolsResolver.ts; src/mcp/viSemanticMcpServerProvider.ts; package.json; docs/consumer-workflows/codespace-preview-cache.devcontainer.json | tests/unit/devToolsResolver.test.ts; tests/unit/viSemanticMcpServerProvider.test.ts; tests/unit/codespacePreviewCacheTemplate.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-677; no per-requirement test exists. |
| VHS-REQ-678 | TEST-678 evidence granularity: file | .github/workflows/marketplace-release.yml; docs/maintainer-operations.md | tests/unit/marketplaceReleaseWorkflow.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-678; no per-requirement test exists. |
| VHS-REQ-679 | TEST-679 evidence granularity: file | src/tooling/devToolsInstaller.ts; src/tooling/devToolsRuntime.ts; src/extension.ts; package.json | tests/unit/devToolsInstaller.test.ts; tests/unit/devToolsRuntime.test.ts; tests/unit/viSemanticMcpServerProvider.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-679; no per-requirement test exists. |
| VHS-REQ-680 | TEST-680 evidence granularity: file | src/tooling/devToolsRuntime.ts; src/extension.ts; package.json; docs/devtools-release.md; docs/mcp-server.md | tests/unit/devToolsRuntime.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-680; no per-requirement test exists. |
| VHS-REQ-681 | TEST-681 evidence granularity: file | scripts/checkGovernanceGates.js; scripts/checkAdrIndex.js; scripts/checkAgentDelegation.js; scripts/auditBranchProtectionSettings.js; scripts/checkDevDependencies.js; scripts/checkDocumentationWorkbench.js | tests/unit/checkGovernanceGatesScript.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-681; no per-requirement test exists. |
| VHS-REQ-683 | TEST-683 evidence granularity: file | scripts/checkBuildInfoIntegrity.js; scripts/generateBuildInfo.js; src/tooling/buildInfo.ts; src/tooling/devHostLoop.ts; src/cli/runDevHost.ts | tests/unit/checkBuildInfoIntegrityScript.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-683; no per-requirement test exists. |
| VHS-REQ-684 | TEST-684 evidence granularity: file | scripts/bootstrapLinuxVsCodeHost.js; scripts/preparePublicRepoClone.js; scripts/publicRepoCloneCore.js; scripts/preparePublicTestFixture.js; scripts/runLinuxIntegrationHost.js; scripts/runWindowsIntegrationHost.js | tests/unit/bootstrapLinuxVsCodeHost.test.ts; tests/unit/preparePublicRepoCloneScript.test.ts; tests/unit/preparePublicTestFixtureScript.test.ts; tests/unit/runLinuxIntegrationHost.test.ts; tests/unit/runWindowsIntegrationHost.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-684; no per-requirement test exists. |
| VHS-REQ-685 | TEST-685 evidence granularity: file | src/tooling/integrationHostStage.ts; tests/integration/runTests.ts; tests/integration/prepareTestWorkspace.ts; tests/integration/suite/index.ts; tsconfig.integration.json | tests/unit/integrationHostStage.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-685; no per-requirement test exists. |
| VHS-REQ-686 | TEST-686 evidence granularity: file | scripts/vagrantLanePreflight.js; scripts/verifyVagrantBox.cjs; scripts/vagrantReleaseValidate.cjs; scripts/vagrantValidationProofDriver.cjs; scripts/lib/vagrantBoxProvenance.cjs; scripts/lib/vagrantDriverArgs.cjs | tests/unit/vagrantLanePreflight.test.ts; tests/unit/verifyVagrantBox.test.ts; tests/unit/vagrantReleaseValidate.test.ts; tests/unit/vagrantValidationProofDriver.test.ts; tests/unit/vagrantBoxProvenance.test.ts; tests/unit/vagrantDriverArgs.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-686; no per-requirement test exists. |
| VHS-REQ-687 | TEST-687 evidence granularity: file | src/tooling/runtimeSettingsLiveSessionProbe.ts; src/tooling/runtimeSettingsLiveSessionProbePacket.ts; src/tooling/runtimeSettingsLiveSessionSafeRestore.ts | tests/unit/runtimeSettingsLiveSessionProbe.test.ts; tests/unit/runtimeSettingsLiveSessionProbePacket.test.ts; tests/unit/runtimeSettingsLiveSessionSafeRestore.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-687; no per-requirement test exists. |
| VHS-REQ-688 | TEST-688 evidence granularity: file | tsconfig.json; .vscode/launch.json; .vscode/tasks.json; .vscode/extensions.json; stryker.config.mjs | tests/unit/developerEnvironmentConfig.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-688; no per-requirement test exists. |
| VHS-REQ-689 | TEST-689 evidence granularity: file | src/cli/runViSemanticMcpServer.ts | tests/unit/runViSemanticMcpServer.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-689; no per-requirement test exists. |
| VHS-REQ-690 | TEST-690 evidence granularity: file | scripts/checkIntegrationCoverageLane.js; .github/workflows/integration-coverage.yml | tests/unit/checkIntegrationCoverageLaneScript.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-690; no per-requirement test exists. |
| VHS-REQ-691 | TEST-691 evidence granularity: file | scripts/readRepoTruth.js; package.json | tests/unit/readRepoTruthScript.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-691; no per-requirement test exists. |
| VHS-REQ-692 | TEST-692 evidence granularity: file | scripts/readRepoTruth.js; package.json | tests/unit/readRepoTruthScript.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-692; no per-requirement test exists. |
| VHS-REQ-693 | TEST-693 evidence granularity: file | scripts/repoGovernanceMcp.js; scripts/readRepoTruth.js; package.json | tests/unit/repoGovernanceMcpScript.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-693; no per-requirement test exists. |
| VHS-REQ-694 | TEST-694 evidence granularity: file | .github/workflows/repo-truth-read-model.yml; scripts/readRepoTruth.js | tests/unit/repoTruthReadModelWorkflow.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-694; no per-requirement test exists. |
| VHS-REQ-695 | TEST-695 evidence granularity: file | scripts/controlPlaneBoardSync.js | tests/unit/controlPlaneBoardSyncScript.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-695; no per-requirement test exists. |
| VHS-REQ-696 | TEST-696 evidence granularity: file | scripts/controlPlaneWrite.js; control-plane-write.json | tests/unit/controlPlaneWriteScript.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-696; no per-requirement test exists. |
| VHS-REQ-697 | TEST-697 evidence granularity: file | scripts/checkEnvSync.js; scripts/installGitHooks.js; .githooks/pre-commit; .githooks/post-merge; .githooks/post-checkout; package.json | tests/unit/checkEnvSyncScript.test.ts; tests/unit/installGitHooksScript.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-697; no per-requirement test exists. |
| VHS-REQ-698 | TEST-698 evidence granularity: file | scripts/renderControlPlaneDigest.js; scripts/controlPlaneApply.js; control-plane-write.json; .github/workflows/control-plane-loop.yml | tests/unit/renderControlPlaneDigestScript.test.ts; tests/unit/controlPlaneLoopWorkflow.test.ts; tests/unit/controlPlaneApplyScript.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-698; no per-requirement test exists. |
| VHS-REQ-699 | TEST-699 evidence granularity: file | src/reporting/comparisonPreviewPipeline.ts; src/reporting/runtime/cycleMeter.ts; src/reporting/comparisonPreviewPipelineIntegration.ts; src/reporting/viPreview/stagedViPreviewValidatorFactory.ts; .github/workflows/windows-container-vi-compare.yml; .github/workflows/linux-container-vi-compare.yml; scripts/req699-linux-container-driver.cjs | tests/unit/comparisonPreviewPipeline.test.ts; tests/unit/comparisonPreviewPipelineIntegration.test.ts; tests/unit/stagedViPreviewValidatorFactory.test.ts; tests/unit/windowsContainerViCompareWorkflow.test.ts; tests/unit/linuxContainerViCompareWorkflow.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-699; no per-requirement test exists. |
| VHS-REQ-700 | TEST-700 evidence granularity: file | scripts/fileLinuxValidationGap.js; scripts/runIssueStandardsTriage.js | tests/unit/fileLinuxValidationGapScript.test.ts; tests/unit/issueStandardsTriageScript.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-700; no per-requirement test exists. |
| VHS-REQ-701 | TEST-701 evidence granularity: file | scripts/auditTraceabilitySteward.js | tests/unit/traceabilityAuditScript.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-701; no per-requirement test exists. |
| VHS-REQ-702 | TEST-702 evidence granularity: file | src/semantic/viChangeClassification.ts; src/semantic/viSemanticModel.ts; src/semantic/viSemanticSchemas.ts | tests/unit/viChangeClassification.test.ts; tests/unit/viSemanticModel.test.ts; tests/unit/viSemanticSchemas.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-702; no per-requirement test exists. |
| VHS-REQ-703 | TEST-703 evidence granularity: file | src/semantic/viPreviewComparisonCorrelation.ts; src/semantic/viSemanticSchemas.ts; src/semantic/viSemanticPrReview.ts; src/semantic/viSemanticReviewMarkdown.ts; src/semantic/viPreviewPairProvider.ts; .github/workflows/vi-semantic-pr-review.yml; .github/workflows/vi-semantic-pr-review-callable.yml; src/cli/runViPreviewCacheWarmer.ts; src/reporting/viPreview/coordinateFramesAcceptance.ts; src/dashboard/comparisonDetailItemGeometry.ts; src/semantic/viSemanticComparisonMcp.ts; src/cli/runViSemanticPrReview.ts; src/semantic/viPreviewRegionCorrelation.ts; src/semantic/viLatentCorpusSample.ts | tests/unit/viPreviewComparisonCorrelation.test.ts; tests/unit/viSemanticPrReview.test.ts; tests/unit/viPreviewPairProvider.test.ts; tests/unit/viSemanticPrReviewWorkflow.test.ts; tests/unit/viPreviewCacheWarmerCli.test.ts; tests/unit/coordinateFramesAcceptance.test.ts; tests/unit/comparisonDetailItemGeometry.test.ts; tests/unit/viLatentCorpusSample.test.ts; tests/unit/viSemanticSchemas.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-703; no per-requirement test exists. Evidence cap: 3 further cited file(s) are listed in docs/testing/wiki-stub-reasons.json. |
| VHS-REQ-704 | TEST-704 evidence granularity: file | .github/workflows/add-to-project.yml | tests/unit/addToProjectWorkflow.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-704; no per-requirement test exists. |
| VHS-REQ-705 | TEST-705 evidence granularity: file | docs/consumer-workflows/copilot-setup-steps.yml; docs/consumer-workflows/copilot-cloud-agent-mcp-runbook.md | tests/unit/copilotSetupStepsTemplate.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-705; no per-requirement test exists. |
| VHS-REQ-706 | TEST-706 evidence granularity: file | scripts/vagrantEmptySwapSpike.cjs; vagrant/empty-swap-hostnative-driver.cjs | tests/unit/vagrantEmptySwapSpike.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-706; no per-requirement test exists. |
| VHS-REQ-707 | TEST-707 evidence granularity: file | docs/architecture/adr/ADR-0028-mirror-mode-dual-real-runtime-validation.md; src/reporting/mirror/mirrorParityDigest.ts; src/reporting/mirror/mirrorCapabilityFingerprint.ts; src/reporting/mirror/mirrorParityReconciler.ts; scripts/recordMirrorBenchmark.js; scripts/reconcileMirrorParity.js; src/reporting/mirror/perfmonSampleSeries.ts; scripts/renderFirstRunPerfmon.js; src/reporting/mirror/perfmonTdmsModel.ts; src/reporting/mirror/perfmonCapturePlan.ts; src/reporting/mirror/firstRunPerfmonPipeline.ts; src/reporting/mirror/perfmonCaptureScript.ts; src/reporting/mirror/perfmonMprrSync.ts; src/reporting/mirror/deterministicRollingBlockRing.ts; src/reporting/mirror/perfmonSessionPattern.ts; src/reporting/mirror/frameTimingAlignment.ts; src/reporting/mirror/perStateRunAnalytics.ts; src/reporting/mirror/crossRuntimePerfDiff.ts; src/reporting/mirror/labviewLaunchTiming.ts | tests/unit/mirrorModeGovernance.test.ts; tests/unit/mirrorCapabilityFingerprint.test.ts; tests/unit/mirrorLeftProducer.test.ts; tests/unit/renderFirstRunPerfmonScript.test.ts; tests/unit/perfmonTdmsModel.test.ts; tests/unit/firstRunPerfmonPipeline.test.ts; tests/unit/perfmonCaptureScript.test.ts; tests/unit/perfmonMprrSync.test.ts; tests/unit/perStateRunAnalytics.test.ts; tests/unit/crossRuntimePerfDiff.test.ts; tests/unit/mprrSharedContract.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-707; no per-requirement test exists. Evidence cap: 10 further cited file(s) are listed in docs/testing/wiki-stub-reasons.json. |
| VHS-REQ-708 | TEST-708 evidence granularity: file | src/reporting/mirror/mirrorMlRow.ts | tests/unit/mirrorMlRow.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-708; no per-requirement test exists. |
| VHS-REQ-710 | TEST-710 evidence granularity: file | docs/architecture/adr/ADR-0029-agent-facing-runtime-and-container-diagnostics.md; docs/architecture/adr/ADR-0032-deterministic-packet-derived-agent-feedback-with-screenshot-cross-check.md; src/reporting/containerDiagnostics/labviewContainerDiagnostics.ts; src/reporting/syncDiagnostics/syncPatternFailureSignature.ts; src/reporting/syncDiagnostics/mprrCalibrationSurface.ts; src/reporting/syncDiagnostics/mprrCalibrationSurfaceRenderer.ts; src/reporting/syncDiagnostics/mprrAgentFeedbackCrossCheck.ts; src/reporting/syncDiagnostics/mprrStripImageDecoder.ts; src/reporting/syncDiagnostics/stopwatchCaptureAccuracy.ts; src/reporting/syncDiagnostics/mprrStopwatchSurfaceRenderer.ts; scripts/diagnoseLabviewContainer.js | tests/unit/labviewContainerDiagnostics.test.ts; tests/unit/diagnoseLabviewContainerScript.test.ts; tests/unit/syncPatternFailureSignature.test.ts; tests/unit/mprrCalibrationSurface.test.ts; tests/unit/mprrCalibrationSurfaceRenderer.test.ts; tests/unit/mprrAgentFeedbackCrossCheck.test.ts; tests/unit/mprrStripImageDecoder.test.ts; tests/unit/stopwatchCaptureAccuracy.test.ts; tests/unit/mprrStopwatchSurfaceRenderer.test.ts; tests/unit/mprrSharedContract.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-710; no per-requirement test exists. |
| VHS-REQ-711 | TEST-711 evidence granularity: file | docs/architecture/adr/ADR-0030-cross-host-empty-swap-comparison-validation.md; src/reporting/comparisonValidation/emptySwapComparisonEvidence.ts | tests/unit/emptySwapComparisonEvidence.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-711; no per-requirement test exists. |
| VHS-REQ-712 | TEST-712 evidence granularity: file | docs/architecture/adr/ADR-0031-labview-free-lvkit-semantic-backend.md; src/semantic/lvkit/lvkitDiffModel.ts; src/semantic/lvkit/lvkitSemanticAdapter.ts; src/semantic/lvkit/lvkitLocator.ts; src/semantic/lvkit/lvkitCompareViRevisions.ts | tests/unit/lvkitDiffModel.test.ts; tests/unit/lvkitSemanticAdapter.test.ts; tests/unit/lvkitLocator.test.ts; tests/unit/lvkitCompareViRevisions.test.ts; tests/unit/lvkitRealIntegration.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-712; no per-requirement test exists. |
| VHS-REQ-713 | TEST-713 evidence granularity: file | scripts/runWindowsRuntimeMatrix.js; scripts/windows-perfmon-mprr-driver.cjs; src/dev/timingStopwatchSurface.ts; src/dev/timingStopwatchHost.ts; src/reporting/mirror/timingCorrelationModel.ts; src/reporting/mirror/timingCorrelationSignature.ts; docs/requirements/runtime-validation-ledger.json; docs/windows-hardening-host.md | tests/unit/runWindowsRuntimeMatrixScript.test.ts; tests/unit/windowsPerfmonMprrPipeline.test.ts; tests/unit/timingStopwatchSurface.test.ts; tests/unit/timingCorrelationModel.test.ts; tests/unit/timingCorrelationSignature.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-713; no per-requirement test exists. |
| VHS-REQ-714 | TEST-714 evidence granularity: file | docs/architecture/adr/ADR-0033-agent-readable-vi-scan-lvkit-generate.md; src/semantic/lvkit/lvkitViScanModel.ts; src/semantic/lvkit/lvkitViScanProvider.ts | tests/unit/lvkitViScanModel.test.ts; tests/unit/lvkitViScanProvider.test.ts; tests/unit/lvkitViScanRealIntegration.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-714; no per-requirement test exists. |
| VHS-REQ-715 | TEST-715 evidence granularity: file | docs/architecture/adr/ADR-0034-full-perfmon-metadata-generic-channels.md; src/reporting/mirror/perfmonSampleSeries.ts; src/reporting/mirror/perfmonCapturePlan.ts | tests/unit/perfmonSampleSeries.test.ts; tests/unit/perfmonCapturePlan.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-715; no per-requirement test exists. |
| VHS-REQ-716 | TEST-716 evidence granularity: file | docs/architecture/adr/ADR-0033-agent-readable-vi-scan-lvkit-generate.md; src/semantic/lvkit/lvkitViScanStore.ts; src/semantic/viSemanticComparisonMcp.ts; src/mcp/viSemanticMcpServerDeps.ts | tests/unit/lvkitViScanStore.test.ts; tests/unit/viSemanticComparisonMcp.test.ts; tests/unit/viSemanticMcpServerDeps.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-716; no per-requirement test exists. |
| VHS-REQ-717 | TEST-717 evidence granularity: file | docs/architecture/adr/ADR-0033-agent-readable-vi-scan-lvkit-generate.md; src/semantic/lvkit/previewTimeViScanTrigger.ts | tests/unit/previewTimeViScanTrigger.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-717; no per-requirement test exists. |
| VHS-REQ-719 | TEST-719 evidence granularity: file | scripts/branchFlowEnforce.js; scripts/collabPromote.js; .githooks/pre-push; scripts/agentGateway.js; scripts/prePushGate.js; scripts/systemCapability.js; scripts/agentLaunchGate.js; .github/workflows/agent-launch-gate-smoke.yml | tests/unit/branchFlowEnforce.test.ts; tests/unit/collabPromote.test.ts; tests/unit/agentGateway.test.ts; tests/unit/prePushGateWiring.test.ts; tests/unit/systemCapability.test.ts; tests/unit/agentLaunchGate.test.ts | File-level evidence: the listed test files pass at the commit and cite VHS-REQ-719; no per-requirement test exists. |

## Diagnostic Test VSIX Check

When a reporter needs to retest a fix before Marketplace publication, manually
dispatch the `Package Test VSIX` workflow from `main`, `release/vX.Y.Z`, or an
exact `vX.Y.Z` tag. It runs the lightweight package checks and uploads
`vi-history-suite-*.vsix` as a short-lived Actions artifact.

Set `publish_prerelease` only when a public immutable prerelease asset is needed
for reporter download. The workflow creates a unique
`diagnostic-test-vsix-<run-id>-<run-attempt>` prerelease and does not edit,
clobber, or reuse an existing GitHub Release. This is diagnostic reporter
support only, not Marketplace publication and not a required release gate.

## Devcontainer Human Check

Inside the devcontainer or Codespace:

1. Wait for `postCreateCommand` and `postStartCommand` to finish.
2. Run `npm run check`.
3. Run `npm test`.
4. Select the `Run VI History Suite` launch configuration and press `F5`.
5. Confirm an Extension Development Host window opens after compile/preLaunch
   completes.
6. Open a trusted Git repository with a tracked LabVIEW file and open
   `VI History`.

If this first-run path fails or a step is unclear, record the environment,
command, and first blocked step in the onboarding tracker:

[Onboarding tracker issue #12](https://github.com/LabVIEW-Community-CI-CD/vi-history-suite/issues/12)

## Maintainer Windows/LabVIEW Check

When the trusted self-hosted runner is available, manually dispatch the
Windows/LabVIEW maintainer workflow on `main`, `release/vX.Y.Z`, or an exact
`vX.Y.Z` tag. It runs the normal package checks plus the Windows extension-host
integration path and uploads the VSIX and environment summary as maintainer
evidence.

This runner is not used for pull requests and is not a required release gate.

## Dependency-Aware Comparison Check

`manual:dependency-harness-newest-tree-staging` (VHS-REQ-624). On a host with a
LabVIEW comparison provider available (a local Docker engine with the
`nationalinstruments/labview:<release>-linux` image is sufficient), verify that a
compared VI loads with its in-repo dependencies present rather than as an
isolated file.

1. Use the `vihs-test-harness-lvdependency` fixture, where `main.vi` depends on
   `Dependencies/dependencies.lvlib` (`data.ctl`, `dependency.vi`).
2. Select the commit window where both the VI and its dependencies changed:
   base `35b92bc` to selected `299c2a5`.
3. Generate a comparison report through the linux-container provider.
4. Confirm the staged tree under `<runDir>/container-out/staging` contains the
   renamed `left-*`/`right-*` VIs beside the materialized `Dependencies/` folder
   and the project file, and that the diagnostics manifest records
   `materializedTree` pinned to the selected revision.
5. Confirm the LabVIEW CLI reports `CreateComparisonReport operation succeeded.`
   and an HTML report is produced.

Expected scope: the report reflects the selected VI's own changes evaluated
against the selected revision's dependencies. Differences confined to shared
library members may not appear independently, matching the dependency caveat
rendered in the report packet. Retain the generated report and the
`<runDir>/diagnostics/diagnostics-manifest.json` as evidence.

This check requires a LabVIEW comparison runtime and is not a required public
PR gate; the deterministic staging contract is covered by
`tests/unit/comparisonReportRuntimeExecution.test.ts`.

## Source Control Semantic Change Hover Check

`manual:source-control-semantic-change-hover` (VHS-REQ-660). The Source Control
semantic change decoration has two states: a modified VI first shows a subtle
pending badge prompting a comparison, and once a working-tree comparison has
produced a narrative for the VI's current change the decoration upgrades to the
semantic "what changed" tooltip (served from cache). On a host with a LabVIEW
comparison provider available (a local Docker engine with the
`nationalinstruments/labview:<release>-linux` image is sufficient), verify both
states end to end:

1. Launch the Extension Development Host (`F5`, `Run VI History Suite`) and open
   a trusted Git repository that contains a tracked LabVIEW VI (for example,
   `ni/actor-framework`). Confirm a comparison runtime is configured with
   `VI History: Set Up Comparison Runtime`.
2. Make an uncommitted edit to a tracked `.vi` so it appears under Source
   Control as a working-tree change, and confirm the VI shows the pending badge
   whose tooltip prompts you to run Compare.
3. Open `VI History` on that VI, select the uncommitted working-tree entry
   paired with the most recent committed revision (HEAD), and choose `Compare`.
   Wait for the comparison to complete with differences.
4. Hover the changed VI in the Source Control view (or the Explorer) and confirm
   the decoration has upgraded to the `VI change: ...` narrative, matching the
   report's what-changed summary.
5. Confirm the decoration clears once it no longer applies: revert or commit the
   edit and confirm the badge is gone after the Source Control view refreshes.

Expected scope: the decoration reflects the HEAD-versus-working-tree change
only. A modified VI shows the pending badge before any comparison; the narrative
tooltip requires a completed working-tree comparison. Comparing the working tree
against an older revision (not HEAD), or comparing two committed revisions, does
not light the narrative decoration by design, and an untrusted workspace shows
no decoration.

This check requires a LabVIEW comparison runtime and is not a required public PR
gate; the cache, recorder, and decoration-resolution logic are covered by
`tests/unit/viSemanticNarrativeCache.test.ts` and
`tests/unit/viSemanticDecorationProvider.test.ts`.

## Marketplace Release Check

Marketplace publication is tag-only and runs only from a manual maintainer
dispatch (no automatic trigger). Create an exact `vX.Y.Z` tag on the
merged `main` commit after release evidence is complete. The `Marketplace
Release` workflow verifies the tag, package version, `origin/main`
reachability, lightweight package checks, pinned VSIX publication, bounded live
Marketplace listing retry, and retained Marketplace listing evidence.
Release evidence names required validation surfaces (traceability audit,
docs-link check, tests, package, Marketplace listing, and closeout
expectation) and retains:

- `release-evidence/marketplace-show.json`
- `release-evidence/marketplace-listing-verification.json`
- `release-evidence/release-evidence-contract.json`
- `coverage/**`
- `vi-history-suite-*.vsix`

## Closeout Evidence Check

Umbrella issue closeout requires generated evidence:

```powershell
npm run closeout:evidence -- --kind standards --issue <issue-number> --run-gates --save-dir assurance-closeout-evidence
```

The closeout command runs `npm run traceability:audit`, `npm run docs:links`,
`npm run dod:gate`, `npm run check`, `npm test`, `npm run coverage:map`, and
`npm run package` when `--run-gates` is set. It always runs standards evidence
and standards toolchain provenance against a temporary tracked-worktree
snapshot built from `git ls-files`, preserving symlink targets as text rather
than following them into generated cache roots. It tries host Python first in
`auto` mode and falls back to the published GitLab registry workbench image
when host preflight is unavailable.
For release closeout, use `--kind release`; the same packet retains quick-triage
standards evidence plus `release-gate` and `26514-review` scorecards, and any
non-PASS or missing release profile gate blocks closure.
When `--save-dir` is provided, closeout evidence writes a machine-readable
`closeout-summary.json` artifact with gate status, standards status, provenance
status, closure-decision state, and `standards.auditTarget` fields for
`mode`, `trackedFileCount`, and `generatedRootsExcluded`.
Remote provenance and registry operations run with bounded timeout windows and
one transient-network retry; auth-denied and credential-helper failures remain
fail-closed and non-retryable.
Docker mode inspects the selected image, pulls the published default when
missing, and reports the selected image plus pull/auth status in closeout
evidence; local images are used only through an explicit `--standards-image`
override. Provenance evidence verifies GitLab source authority, the private
GitHub mirror, `v0.2.19`, the local non-authoritative skill cache, and registry
image access. The DoD parser reports explicit `PASS`, `N/A`, or `FAIL` and only
lets scanner-visible evidence in `.github/workflows/ci.yml` promote DoD to
`PASS`; generated `assurance-*-evidence` outputs and unit-test fixtures are
disqualified sources. A summary is not closable until local gates, mandatory
standards evidence, standards provenance, and Definition-of-Done evidence are
clean or tied to a blocking follow-up issue.

## PR Evidence Contract

Requirement-scoped pull requests must keep a lightweight evidence surface and
name the linked issue with `Refs #...` unless the PR actually completes the
closeout contract. PR evidence must include the target requirement, validation commands,
and traceability/RTM impact; it must also include an out-of-scope statement and
closeout readiness. Keep required hosted CI checks, local gates, targeted tests,
standards provenance or closeout status, and environment blockers explicit.
Local validation evidence includes `npm run traceability:audit`,
`npm run docs:links`, `npm run check`, `npm test`, `npm run coverage:map`,
`npm run package`, and the targeted tests for the changed requirement or
implementation surface. If optional/authenticated evidence is blocked, note the
blocker and the follow-up issue.

## Optional Vagrant Check

When isolated local validation is useful and Vagrant plus a compatible
Windows/LabVIEW box are already available:

```bash
npm run vagrant:validate
cd vagrant
vagrant up
```

Vagrant evidence is useful local confidence only. It is not required for a
release.

## Wiki Canonical Test Pages

The `Wiki Canonical Test Pages` CI job turns the vitest run into execution evidence and
checks that the wiki's test pages regenerate from `docs/` with a stimulus and required
observation items. It runs `npx vitest run --reporter=json --outputFile=vitest-report.json`,
`python3 .repo-standards-review/observations.py evidence --format jest-json`, and
`python3 scripts/check_wiki_canonical.py`, which builds the wiki twice, requires identical
output, and runs `observations.py check --member-commit`. A test page is canonical only when
the test files its requirements' `Evidence Files` block names ran and passed at the same
commit; otherwise it stays a stub. The extension-host suite is not part of this evidence, so a
page that names it says `Not verified here`.

Counts always state their granularity: **22 per-case plus 115 file-level canonical, 4 stub**. A per-case page
is one of the 22 rows written by hand above; its requirement's test files list their cases. A file-level page
(its title says `evidence granularity: file`) names the test files that passed at the commit and cite the
requirement's ID; no per-requirement test exists, and the page does not claim that a file verifies the whole
requirement. The 4 stubs (VHS-REQ-004, 084, 599 and 607) are cited only by the generic `requirementsDocs.test.ts` and
`packageManifest.test.ts`, which are never evidence for a specific requirement; `docs/testing/wiki-stub-reasons.json`
holds their reason codes, the expected counts and every file omitted by the page-margin cap, and
`scripts/check_wiki_canonical.py` fails when a page or count differs from it.

`scripts/generate_wiki_test_plan.py` writes the file-level and stub rows of the table above, the `Evidence Files`
block of each requirement in `docs/requirements/srs.md` (the section the test pages read) and the JSON file from the
SRS Verification References, the test files' text and the evidence; rerun it with `wiki-evidence.json` present after
changing a cited test file. Every test page keeps at least 2,048 bytes below the 16,384-byte page budget: the script
omits the file with the most test cases from a requirement's block until it does, records each omission in the JSON
file and counts it in the block, and the checker fails below that margin (`--self-test` is its negative control).
The generator's own split of long non-test pages leaves them closer to the budget; that needs a kit change.
