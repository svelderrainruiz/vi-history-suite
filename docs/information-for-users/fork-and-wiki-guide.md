# Fork and wiki guide

> How to fork this repository and publish your own copy of its wiki. Aligns to
> **ISO/IEC/IEEE 26514:2022 §5**. See also the [Delivery Profile](./delivery-profile.md)
> and the [Navigation and Search](./navigation-and-search.md) guide.

The wiki is generated from `docs/`, which is the single source of truth. A fork
publishes its **own** wiki from its **own** `docs/`; it never writes to the
upstream wiki.

## Bootstrap checklist

1. **Fork** the repository on GitHub. Keep the default branch name `develop`:
   the workflow publishes from that branch only.
2. **Enable Actions** on the fork (Actions tab, or
   `gh api -X PUT repos/<fork>/actions/permissions -F enabled=true -f allowed_actions=all`).
   A fork's workflows are not registered, and a push may not start them, until
   Actions is enabled and a push has touched `.github/workflows/`; start
   `wiki-publish` with *Run workflow* if a push does not.
3. **Enable the wiki** (Settings, Features, Wiki) and **create the first page in
   the web UI** (any title, any text). A fork's `<fork>.wiki.git` repository does
   not exist until a page is created, so the first clone or push fails without
   this step. The workflow overwrites that page.
4. **Point the generator at your fork.** In `.wiki-generator.json` set `repoUrl`
   (and any URL in `description`) to your fork, so wiki links resolve to your
   repository instead of the upstream one. The job succeeds without this edit,
   but the generated pages then link to the upstream. The generated Home page
   replaces the page you created, so put any fork notice in `description`.
5. **Opt in.** Create the repository variable `WIKI_PUBLISH_ENABLED` with the value
   `true` (Settings, Secrets and variables, Actions, Variables). Without it the
   `wiki-publish` job is skipped on a fork (fail closed). On the upstream it runs
   without the variable.
6. **Run the workflow.** Push to `develop` or start `wiki-publish` from the
   Actions tab. The job uses only the fork's own `GITHUB_TOKEN`
   (`contents: write`) and pushes only to the fork's own wiki. It needs no
   secrets.

## What breaks on a fork

- **Marketplace publishing.** `marketplace-release.yml` is manual (dispatch) and
  runs in the protected `marketplace-release` environment, which reads the
  `VSCE_PAT` secret. A fork has neither the environment nor the secret, so the
  release fails closed at its authority guard. A fork that wants to publish needs
  its own publisher and secret.
- **Self-hosted runners.** The LabVIEW maintainer, runtime-matrix and integration
  coverage workflows (`linux-labview-maintainer.yml`, `windows-labview-maintainer.yml`,
  `windows-runtime-matrix.yml`, `integration-coverage.yml`) target self-hosted
  runners with specific labels. On a fork they stay queued until you register your
  own runners with those labels. The main `ci.yml` jobs use GitHub-hosted runners.
- **Project tokens.** Workflows that use `CONTROL_PLANE_PROJECT_TOKEN`,
  `PREVIEW_CACHE_TARGET_TOKEN` or `VI_REVIEW_TARGET_TOKEN` need those secrets and
  cannot act on the upstream's projects or repositories from a fork.
- **Test pages.** The wiki test pages show the evidence the job produced on your
  fork at your commit. Tests that need a VS Code extension host are not run by the
  job, so their pages say *not run*; they are never shown as passed.
- **Expected counts.** `scripts/check_wiki_canonical.py` compares the number of
  canonical and stub test pages with `docs/testing/wiki-stub-reasons.json`. If your
  fork changes the tests or docs, update that file or the job stops before
  publishing (fail closed).
- **Network access.** The job installs a pinned `lvkit` and fetches two pinned
  commits of a public LabVIEW repository, as the upstream CI does.

## Sending evidence upstream (issues built, pull requests planned)

The submission **issue** path is built
([ADR-0036](../architecture/adr/ADR-0036-verify-fork-wiki-submissions-as-data.md)).
The pull request path for page changes, the lineage field on pages and the
accept step are not built yet. The intended design is:

- The upstream keeps a private partner **allow-list**. It is unset by default,
  so by default no submission is accepted.
- Only **attested** evidence counts: the upstream re-verifies the submitted
  evidence with its own pinned verifier code, in an isolated job, against its own
  test definitions. The fork's scripts are never run with upstream privileges, and
  fork content is treated as data. Evidence that is not verified is labelled
  *not attested*.
- Each page carries a **lineage** field (source repository and commit) that the
  fork owns; the upstream records only submissions it accepted.

### How a partner submits an issue

1. The upstream operator lists your fork's owner (your user or organisation
   login, optionally pinned to its numeric account id) in the upstream's
   private partner allow-list. Nothing is enabled until the operator does so:
   an unset or empty list rejects every submission, and the list is not
   published. You must be that owner, or a public member of the owning
   organisation, to submit.
2. Run the tests on your fork at a pushed commit (`fork_commit`) and commit the
   resulting `wiki-evidence.json` (`rsr/test-evidence@1`, one platform) in a
   later commit (`evidence_commit`): the generator records the commit it ran
   at, which cannot be the commit that adds the evidence file itself. The
   evidence must record `commit == fork_commit`, and `evidence_commit` must be
   `fork_commit` or ahead of it in your fork.
3. Open an issue on the upstream titled `[wiki-submission] <anything>` whose
   body is **only** one JSON document of schema `rsr/wiki-submission@1`
   (`scripts/wiki-submission.schema.json`): your fork, the full 40-hex fork
   commit and evidence commit, the upstream base commit, generator version,
   platform, the test ids with their results, the evidence files with their
   sha256, and the lineage (source repository and commit). Editing the issue
   re-runs verification; renaming the title away from the prefix withdraws an
   earlier attestation.
4. The workflow answers with the label `wiki-attested` or `wiki-not-attested`
   and a fixed comment that names the upstream commit that verified it and a
   reason code.

**What attested means.** The fork owner is a listed partner and you are that
owner or a public member of it, the fork is a fork of this repository, the
evidence files fetched from your fork at that commit match the declared sha256
and size limits, and the test ids, results, commit and platform agree with this
repository's own test files (`testPlan.canonical` in `.wiki-generator.json`).
Nothing from your fork is checked out or run, and none of your text is echoed
back. Attested is not a claim that your code is correct.
