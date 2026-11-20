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
2. **Enable Actions** on the fork (Actions tab). A fork starts with workflows
   disabled.
3. **Enable the wiki** (Settings, Features, Wiki) and **create the first page in
   the web UI** (any title, any text). A fork's `<fork>.wiki.git` repository does
   not exist until a page is created, so the first clone or push fails without
   this step. The workflow overwrites that page.
4. **Point the generator at your fork.** In `.wiki-generator.json` set `repoUrl`
   (and any URL in `description`) to your fork, so wiki links resolve to your
   repository instead of the upstream one.
5. **Opt in.** Create the repository variable `WIKI_PUBLISH_ENABLED` with the value
   `true` (Settings, Secrets and variables, Actions, Variables). Without it the
   `wiki-publish` job is skipped on a fork (fail closed). On the upstream it runs
   without the variable.
6. **Run the workflow.** Push to `develop` or start `wiki-publish` from the
   Actions tab. The job uses only the fork's own `GITHUB_TOKEN`
   (`contents: write`) and pushes only to the fork's own wiki. It needs no
   secrets.

## What breaks on a fork

- **Marketplace and publisher secrets.** The release workflows publish the
  extension and need secrets that exist only on the upstream. They fail or skip on
  a fork. Do not add publisher credentials to a fork to make them pass.
- **Self-hosted runners.** Workflows that target self-hosted or LabVIEW-equipped
  runners stay queued on a fork until you register your own runners.
- **Test pages.** The wiki test pages show the evidence the job produced on your
  fork at your commit. Tests that need a VS Code extension host are not run by the
  job, so their pages say *not run*; they are never shown as passed.
- **Expected counts.** `scripts/check_wiki_canonical.py` compares the number of
  canonical and stub test pages with `docs/testing/wiki-stub-reasons.json`. If your
  fork changes the tests or docs, update that file or the job stops before
  publishing (fail closed).
- **Network access.** The job installs a pinned `lvkit` and fetches two pinned
  commits of a public LabVIEW repository, as the upstream CI does.

## Sending evidence upstream (planned, not built)

Nothing in this section exists yet. The intended design is:

- A fork submits evidence to the upstream through an **issue** (a form with a
  structured record), and through a **pull request** for page changes, with
  evidence files attached.
- The upstream keeps a partner **allow-list**. It ships **empty**, so by default
  no submission is accepted.
- Only **attested** evidence counts: the upstream re-verifies the submitted
  evidence with its own pinned verifier code, in an isolated job, against its own
  test definitions. The fork's scripts are never run with upstream privileges, and
  fork content is treated as data. Evidence that is not verified is labelled
  *not attested*.
- Each page carries a **lineage** field (source repository and commit) that the
  fork owns; the upstream records only submissions it accepted.
