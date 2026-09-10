"""研究計算を使わず、承認境界だけを検証する。"""
import copy
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import harness


class HarnessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'requirements.md').write_text(
            '# 要件\n## R1\n人が選んだ方法A。\n## R2\n別作業。\n', encoding='utf-8')
        self.order = {
            'schema_version': 1, 'id': 'fixture-only',
            'scope': {
                'objective': '指定されたR1のみ実装', 'task_refs': ['task-1'],
                'decisions': {'method': '方法A'}, 'unresolved': [],
                'references': [{'path': 'requirements.md', 'heading': '## R1'}],
                'operations': {
                    'implement': {'write_files': ['src/change.py'], 'commands': []},
                    'test': {'write_files': [], 'commands': [['python3', '-m', 'unittest', 'test_local']]},
                },
                'presentation': None,
            },
            'state': {'phase': 'ready'}, 'approvals': {},
        }

    def approve(self, action):
        self.order['approvals'][action] = {
            'scope_hash': harness.scope_hash(self.order, self.root),
            'user_message': 'isolated-test:user-1',
            'user_quote': 'テストfixture内の仮承認。実研究には利用不可。',
        }

    def check(self, action='implement', **kwargs):
        if action == 'implement':
            kwargs.setdefault('write_files', ['src/change.py'])
        return harness.check(self.order, self.root, action, **kwargs)

    def test_missing_approval_is_rejected(self):
        with self.assertRaisesRegex(harness.Rejected, '承認'):
            self.check()

    def test_scoped_implementation_is_allowed(self):
        self.approve('implement')
        self.check(write_files=['src/change.py'])

    def test_review_is_not_human_approval(self):
        self.order['approvals']['implement'] = {'approved': True, 'review': 'PASS'}
        with self.assertRaises(harness.Rejected):
            self.check()

    def test_unresolved_science_stops_implementation(self):
        self.order['scope']['unresolved'] = ['生成法の採用判断']
        self.approve('implement')
        with self.assertRaisesRegex(harness.Rejected, '未決'):
            self.check()

    def test_decision_change_invalidates_approval(self):
        self.approve('implement')
        self.order['scope']['decisions']['method'] = '勝手に方法B'
        with self.assertRaisesRegex(harness.Rejected, 'hash'):
            self.check()

    def test_selected_section_change_invalidates_approval(self):
        self.approve('implement')
        p = self.root / 'requirements.md'
        p.write_text(p.read_text().replace('方法A', '方法B'))
        with self.assertRaisesRegex(harness.Rejected, 'hash'):
            self.check()

    def test_unrelated_section_and_notes_preserve_approval(self):
        self.approve('implement')
        p = self.root / 'requirements.md'
        p.write_text(p.read_text().replace('別作業。', '別作業の修正。'))
        self.order['notes'] = '相談中の候補。作業指示ではない。'
        self.check()

    def test_scope_expansion_invalidates_approval(self):
        self.approve('implement')
        self.order['scope']['operations']['implement']['write_files'].append('runs/new/result.json')
        with self.assertRaises(harness.Rejected):
            self.check()

    def test_approval_does_not_transfer_between_orders_or_roots(self):
        self.approve('implement')
        self.order['id'] = 'other-task'
        with self.assertRaises(harness.Rejected):
            self.check()
        self.order['id'] = 'fixture-only'
        with tempfile.TemporaryDirectory() as other:
            with self.assertRaises(harness.Rejected):
                harness.check(self.order, Path(other), 'implement')

    def test_test_permission_is_separate(self):
        self.approve('implement')
        with self.assertRaises(harness.Rejected):
            self.check('test')
        self.approve('test')
        self.check('test', command=['python3', '-m', 'unittest', 'test_local'])
        with self.assertRaises(harness.Rejected):
            self.check('test', command=['julia', 'run.jl'])

    def test_experiments_are_never_dispatched(self):
        self.approve('experiment')
        with self.assertRaisesRegex(harness.Rejected, '本人'):
            self.check('experiment')

    def test_blocked_and_draft_do_not_transition(self):
        self.approve('implement')
        for phase in ['draft', 'blocked', 'complete']:
            with self.subTest(phase=phase):
                self.order['state'] = {'phase': phase, 'return_to': 'consult'}
                with self.assertRaises(harness.Rejected):
                    self.check()

    def test_write_scope_is_exact_and_stays_inside_root(self):
        self.approve('implement')
        for name in ['src/other.py', '../outside.py', '/tmp/out.py', '.', 'src/*.py']:
            with self.subTest(name=name), self.assertRaises(harness.Rejected):
                self.check(write_files=[name])

    def test_symlink_escape_is_rejected(self):
        with tempfile.TemporaryDirectory() as other:
            (self.root / 'src').symlink_to(other, target_is_directory=True)
            with self.assertRaises(harness.Rejected):
                self.approve('implement')

    def test_symlink_to_unlisted_internal_file_is_rejected(self):
        (self.root / 'src').mkdir()
        (self.root / 'src/change.py').symlink_to(self.root / 'requirements.md')
        with self.assertRaises(harness.Rejected):
            self.approve('implement')

    def test_code_fence_does_not_shorten_approved_section(self):
        p = self.root / 'requirements.md'
        p.write_text('## R1\n```md\n## Example\n```\n条件A\n## R2\n別作業\n')
        self.approve('implement')
        p.write_text(p.read_text().replace('条件A', '条件B'))
        with self.assertRaises(harness.Rejected):
            self.check()

    def test_test_without_actual_command_is_rejected(self):
        self.approve('test')
        with self.assertRaises(harness.Rejected):
            self.check('test')

    def test_implementation_requires_actual_write_target(self):
        self.approve('implement')
        with self.assertRaises(harness.Rejected):
            self.check(write_files=[])

    def test_test_cannot_write_implementation_target(self):
        self.approve('test')
        with self.assertRaises(harness.Rejected):
            self.check('test', command=['python3', '-m', 'unittest', 'test_local'],
                       write_files=['src/change.py'])

    def test_slides_cannot_write_implementation_target(self):
        self.slides()
        with self.assertRaises(harness.Rejected):
            self.check('slides', write_files=['src/change.py'])

    def test_blank_human_reference_is_rejected(self):
        self.approve('implement')
        self.order['approvals']['implement']['user_quote'] = '   '
        with self.assertRaises(harness.Rejected):
            self.check()

    def test_presentation_evidence_must_be_hash_bound(self):
        self.slides()
        self.order['scope']['presentation']['figures']['F1']['inputs'] = ['unbound.csv']
        with self.assertRaises(harness.Rejected):
            self.check('slides')

    def test_missing_or_ambiguous_section_is_rejected(self):
        for body in ['## Other\n本文', '## R1\n本文\n## R1\n本文']:
            (self.root / 'requirements.md').write_text(body)
            with self.assertRaises(harness.Rejected):
                harness.scope_hash(self.order, self.root)

    def test_unknown_schema_and_typo_fail_closed(self):
        for key, value in [('schema_version', 2), ('scope', [])]:
            order = copy.deepcopy(self.order)
            order[key] = value
            with self.assertRaises(harness.Rejected):
                harness.scope_hash(order, self.root)
        self.order['scope']['write_filez'] = ['other.py']
        with self.assertRaises(harness.Rejected):
            harness.scope_hash(self.order, self.root)

    def slides(self):
        self.order['scope']['operations'] = {
            'slides': {'write_files': ['slides.md', 'figure.svg'], 'commands': []},
        }
        self.order['scope']['presentation'] = {
            'claims': {'C1': {'text': 'fixtureのA/B比較', 'evidence': ['requirements.md']}},
            'figures': {'F1': {
                'inputs': ['requirements.md'], 'series': ['A', 'B'],
                'transform': 'none', 'axes': {'x': 'case', 'y': 'K'},
                'claims': ['C1'],
            }},
        }
        self.approve('slides')
        (self.root / 'slides.md').write_text('fixture draft')
        return {
            'presentation': copy.deepcopy(self.order['scope']['presentation']),
            'artifacts': [{'path': 'slides.md', 'sha256': hashlib.sha256(b'fixture draft').hexdigest()}],
        }

    def test_slides_require_separate_approval(self):
        self.approve('implement')
        with self.assertRaises(harness.Rejected):
            self.check('slides')

    def test_extra_series_or_transform_or_claim_is_rejected(self):
        manifest = self.slides()
        self.check('slides', manifest=manifest)
        for key, value in [('series', ['A', 'B', 'counterexample']), ('transform', 'normalize')]:
            changed = copy.deepcopy(manifest)
            changed['presentation']['figures']['F1'][key] = value
            with self.assertRaises(harness.Rejected):
                self.check('slides', manifest=changed)
        manifest['presentation']['claims']['C2'] = {'text': 'new', 'evidence': []}
        with self.assertRaises(harness.Rejected):
            self.check('slides', manifest=manifest)

    def test_changed_image_bytes_are_rejected(self):
        manifest = self.slides()
        (self.root / 'slides.md').write_text('silent extra content')
        with self.assertRaises(harness.Rejected):
            self.check('slides', manifest=manifest)

    def test_present_requires_human_explanation_receipt_bound_to_output(self):
        manifest = self.slides()
        with self.assertRaises(harness.Rejected):
            self.check('present', manifest=manifest)
        self.order['presentation_acceptance'] = {
            'scope_hash': harness.scope_hash(self.order, self.root),
            'manifest_hash': harness.json_hash(manifest),
            'user_message': 'isolated-test:user-2', 'user_quote': 'この図を説明できる。',
            'explanation_confirmed': True,
        }
        self.check('present', manifest=manifest)
        self.order['presentation_acceptance']['explanation_confirmed'] = False
        with self.assertRaises(harness.Rejected):
            self.check('present', manifest=manifest)

    def test_usage_unknown_is_not_zero(self):
        result = harness.summarize_usage([
            {'requested_model': 'terra', 'effective_model': None, 'tokens': None},
            {'requested_model': 'sol', 'effective_model': 'sol', 'tokens': 12},
        ])
        self.assertIsNone(result['total_tokens'])
        self.assertEqual(result['known_tokens'], 12)
        self.assertEqual(result['unavailable_token_records'], 1)

    def test_duplicate_json_keys_rejected(self):
        p = self.root / 'bad.json'
        p.write_text('{"scope": {}, "scope": {"unresolved": []}}')
        with self.assertRaises(harness.Rejected):
            harness.read_json(p)

    def test_cli_pass_and_reject_exit_codes(self):
        self.approve('implement')
        p = self.root / 'order.json'
        p.write_text(json.dumps(self.order), encoding='utf-8')
        cli = [sys.executable, '-B', str(Path(harness.__file__).resolve()),
               'check', str(p), '--root', str(self.root)]
        passed = subprocess.run(cli + ['--action', 'implement', '--write', 'src/change.py'],
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(passed.returncode, 0, passed.stdout + passed.stderr)
        self.assertEqual(json.loads(passed.stdout)['status'], 'RECORD_CHECK_PASS')
        rejected = subprocess.run(cli + ['--action', 'experiment'],
                                  capture_output=True, text=True, timeout=5)
        self.assertEqual(rejected.returncode, 2, rejected.stdout + rejected.stderr)
        self.assertEqual(json.loads(rejected.stdout)['status'], 'REJECTED')
        self.assertFalse((self.root / 'src/change.py').exists())

    def test_changed_output_with_updated_manifest_still_needs_human_confirmation(self):
        manifest = self.slides()
        self.order['presentation_acceptance'] = {
            'scope_hash': harness.scope_hash(self.order, self.root),
            'manifest_hash': harness.json_hash(manifest),
            'user_message': 'isolated-test:user-2', 'user_quote': '説明できる。',
            'explanation_confirmed': True,
        }
        (self.root / 'slides.md').write_text('new draft')
        manifest['artifacts'][0]['sha256'] = hashlib.sha256(b'new draft').hexdigest()
        self.check('slides', manifest=manifest)
        with self.assertRaises(harness.Rejected):
            self.check('present', manifest=manifest)

    def test_implementation_and_presentation_cannot_share_order(self):
        self.slides()
        self.order['scope']['operations']['implement'] = {'write_files': ['src/change.py'], 'commands': []}
        with self.assertRaises(harness.Rejected):
            self.approve('implement')

    def test_slides_preflight_needs_actual_write(self):
        self.slides()
        self.check('slides', write_files=['slides.md'])
        with self.assertRaises(harness.Rejected):
            self.check('slides')


if __name__ == '__main__':
    unittest.main()
