import { spawnSync } from 'node:child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';

import { describe, expect, it } from 'vitest';

const root = path.resolve(__dirname, '..', '..');
const workflow = fs
  .readFileSync(path.join(root, '.github', 'workflows', 'wiki-submission-ingest.yml'), 'utf8')
  .replace(/\r\n/g, '\n');

// VHS-REQ-720: a fork's wiki submission is verified as data. The verifier is
// stdlib Python; its offline fixtures live in tests/python and run here.
describe('Wiki submission ingest (VHS-REQ-720)', () => {
  it('passes the offline verifier fixtures (VHS-REQ-720.1, VHS-REQ-720.2, VHS-REQ-720.3)', () => {
    const python = ['python3', 'python', 'py'].find(
      (candidate) =>
        spawnSync(candidate, ['-c', 'import sys; sys.exit(sys.version_info < (3, 9))']).status === 0
    );
    expect(python).toBeDefined();
    const result = spawnSync(
      python as string,
      ['-B', '-m', 'unittest', 'discover', '-s', 'tests/python', '-p', 'wiki_submission_test.py'],
      { cwd: root, encoding: 'utf8', env: { ...process.env, PYTHONDONTWRITEBYTECODE: '1' } }
    );
    expect(result.stderr + result.stdout).toMatch(/OK/);
    expect(result.status).toBe(0);
  });

  it('reads the allow-list secret only in the gate job and never runs fork code (VHS-REQ-720.1)', () => {
    expect(workflow.match(/secrets\.SUBMISSION_ALLOWLIST/g)).toHaveLength(1);
    expect(workflow).not.toMatch(/^\s*pull_request_target:/m);
    expect(workflow).not.toContain('github.event.issue.body');
    expect(workflow).toMatch(/ref: \$\{\{ github\.sha \}\}/);
  });

  it('reports a fixed vocabulary and still reports when the gate crashes (VHS-REQ-720.3)', () => {
    const report = workflow.slice(workflow.indexOf('  report:'));
    const condition = report.split('\n').find((line) => line.trim().startsWith('if:')) ?? '';
    expect(condition).toContain("always() && needs.gate.result != 'skipped'");
    expect(condition).toContain("needs.gate.outputs.authorized != 'yes'");
    expect(report).toContain('wiki-attested');
    expect(report).toContain('wiki-not-attested');
  });
});
