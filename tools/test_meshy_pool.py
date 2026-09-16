"""Offline failure/recovery checks. Never reads real credentials or calls Meshy."""
import contextlib
import io
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import meshy_pool as pool


class FakeApi:
    def __init__(self, credits=None):
        self.credits = credits or {'one': 1100, 'two': 1100}
        self.posts, self.tasks, self.downloads = [], {}, []
        self.post_error = None
        self.pending = False
        self.extra_charge = 0
        self.fail_download = False

    def balance(self, account):
        return self.credits[account['id']]

    def call(self, account, method, route, payload=None):
        if method == 'POST':
            self.posts.append((account['id'], route, payload))
            if self.post_error is not None:
                raise pool.ApiError(self.post_error)
            cost = (10 if payload.get('mode') == 'refine' else
                    30 if 'image_url' in payload and payload['should_texture'] else 20)
            self.credits[account['id']] -= cost
            task_id = f'task-{len(self.posts):04}'
            self.tasks[task_id] = (account['id'], cost)
            return {'result': task_id}
        task_id = route.rsplit('/', 1)[-1]
        owner, cost = self.tasks[task_id]
        assert owner == account['id'], 'Task polled with a different account'
        return {'id': task_id, 'status': 'PENDING' if self.pending else 'SUCCEEDED',
                'consumed_credits': cost + self.extra_charge,
                'model_urls': {'glb': 'https://example.invalid/model.glb'}}

    def download(self, url, dest):
        self.downloads.append(str(dest))
        if self.fail_download:
            raise pool.Stop('DOWNLOAD_FAILED_RESUME_SAME_TASK')
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(struct.pack('<4sII', b'glTF', 2, 12))
        return {'file': str(dest.relative_to(pool.ROOT)), 'bytes': 12,
                'sha256': pool.digest(dest.read_bytes())}


class PoolTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='meshy-pool-test-')
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        for name, value in {'ROOT': root, 'PRIVATE': root/'private',
                'OUTPUT': root/'exports', 'SECRETS': root/'secrets',
                'CONFIG': root/'secrets/accounts.json'}.items():
            self.stack.enter_context(patch.object(pool, name, value))
        self.stack.enter_context(patch('urllib.request.OpenerDirector.open',
                                      side_effect=AssertionError('Network forbidden in tests')))
        self.stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
        self.plan_file = root/'jobs.json'
        self.account_list = [{'id': name, '_key': 'fake', '_fingerprint': name,
                             '_cny_per_credit': 12/1100} for name in ('one', 'two')]
        self.api = FakeApi()
        self.plan(1)

    def plan(self, count, **settings):
        result = {'id': 'test-batch', 'texture': '4k', 'budget_credits': count*30,
                  'jobs': [{'id': f'item-{i}', 'prompt': 'One simple chair'} for i in range(count)]}
        result.update(settings)
        pool.write(self.plan_file, result)

    def pipeline(self):
        return pool.Pipeline(self.plan_file, self.api, self.account_list)

    def test_complete_and_restart_no_new_charges(self):
        self.plan(2)
        run = self.pipeline()
        self.assertFalse(run.tick())
        self.assertEqual(len(self.api.posts), 2)
        self.assertFalse(run.tick())
        self.assertTrue(run.tick())
        self.assertTrue(self.pipeline().tick())
        self.assertEqual(len(self.api.posts), 4)
        self.assertEqual(run.report()['provider_reported_credits'], 60)
        self.assertEqual(run.report()['unknown_charge_stages'], 0)
        self.assertEqual([p[0] for p in self.api.posts], ['one', 'two', 'one', 'two'])

    def test_timeout_no_resubmission_after_restart(self):
        self.api.post_error = 0
        with self.assertRaisesRegex(pool.Stop, 'NO_AUTO_RETRY'): self.pipeline().tick()
        self.api.post_error = None
        with self.assertRaisesRegex(pool.Stop, 'uncertain'): self.pipeline().tick()
        self.assertEqual(len(self.api.posts), 1)

    def test_crash_after_submission_record_is_not_replayed(self):
        run = self.pipeline()
        run.tick()
        run.state['jobs']['item-0']['stages']['preview'] = {'status': 'submitting', 'expected_credits': 20}
        run.save()
        with self.assertRaisesRegex(pool.Stop, 'submitting'): self.pipeline().tick()
        self.assertEqual(len(self.api.posts), 1)

    def test_rate_limit_stops_before_switching_accounts(self):
        self.plan(3)
        self.api.post_error = 429
        with self.assertRaisesRegex(pool.Stop, '429_NO_AUTO_RETRY'): self.pipeline().tick()
        self.assertEqual(len(self.api.posts), 1)
        with self.assertRaisesRegex(pool.Stop, 'rejected'): self.pipeline().tick()

    def test_balance_requires_full_mesh_and_texture(self):
        self.api.credits = {'one': 29, 'two': 30}
        run = self.pipeline()
        run.tick()
        self.assertEqual(self.api.posts[0][0], 'two')
        run.tick()
        self.assertEqual(self.api.posts[1][0], 'two')
        self.assertTrue(run.tick())
        self.assertEqual(self.api.credits['two'], 0)

    def test_no_account_can_fund_full_model(self):
        self.api.credits = {'one': 20, 'two': 20}
        with self.assertRaisesRegex(pool.Stop, 'NO_ACCOUNT_CAN_FUND'): self.pipeline().tick()
        self.assertEqual(self.api.posts, [])

    def test_one_active_model_per_account(self):
        self.plan(3)
        run = self.pipeline()
        self.api.pending = True
        run.tick(10)
        run.tick(10)
        self.assertEqual(len(self.api.posts), 2)

    def test_concurrency_limit(self):
        self.plan(3)
        run = self.pipeline()
        self.api.pending = True
        run.tick(1)
        run.tick(1)
        self.assertEqual(len(self.api.posts), 1)

    def test_download_retry_fetches_same_task(self):
        run = self.pipeline()
        run.tick()
        run.tick()
        self.api.fail_download = True
        with self.assertRaisesRegex(pool.Stop, 'DOWNLOAD_FAILED'): run.tick()
        self.api.fail_download = False
        self.assertTrue(self.pipeline().tick())
        self.assertEqual(len(self.api.posts), 2)

    def test_plan_change_on_restart_is_blocked(self):
        self.pipeline().tick()
        self.plan(1, texture='2k')
        with self.assertRaisesRegex(pool.Stop, 'PLAN_CHANGED'): self.pipeline()

    def test_key_change_on_restart_is_blocked(self):
        self.pipeline().tick()
        self.account_list[0]['_fingerprint'] = 'different-key'
        with self.assertRaisesRegex(pool.Stop, 'KEY_MISSING_OR_CHANGED'): self.pipeline()

    def test_low_budget_cannot_submit(self):
        self.plan(1, budget_credits=29)
        with self.assertRaisesRegex(pool.Stop, 'BUDGET_TOO_SMALL'): self.pipeline()
        self.assertEqual(self.api.posts, [])

    def test_unexpected_price_stops_before_refine(self):
        run = self.pipeline()
        run.tick()
        self.api.extra_charge = 5
        with self.assertRaisesRegex(pool.Stop, 'COST_EXCEEDED'): run.tick()
        self.assertEqual(len(self.api.posts), 1)

    def test_image_is_single_stage_with_texture(self):
        image = pool.ROOT/'source.png'
        image.write_bytes(b'\x89PNG\r\n\x1a\nfixture')
        self.plan(1, jobs=[{'id': 'image-job', 'mode': 'image', 'image_file': 'source.png'}])
        run = self.pipeline()
        run.tick()
        self.assertTrue(run.tick())
        self.assertEqual(len(self.api.posts), 1)
        self.assertTrue(self.api.posts[0][2]['should_texture'])
        self.assertEqual(run.report()['provider_reported_credits'], 30)

    def test_changed_source_image_blocked_before_submit(self):
        image = pool.ROOT/'source.png'
        image.write_bytes(b'\x89PNG\r\n\x1a\nfixture')
        self.plan(1, jobs=[{'id': 'image-job', 'mode': 'image', 'image_file': 'source.png'}])
        run = self.pipeline()
        image.write_bytes(b'\x89PNG\r\n\x1a\nchanged')
        with self.assertRaisesRegex(pool.Stop, 'SOURCE_IMAGE_CHANGED'): run.tick()
        self.assertEqual(self.api.posts, [])

    def test_unknown_charge_is_not_reported_as_zero_cost(self):
        run = self.pipeline()
        run.tick()
        report = run.report()
        self.assertEqual(report['unknown_charge_stages'], 1)
        self.assertIsNone(report['jobs'][0]['actual_cny_prorated'])

    def test_duplicate_key_is_rejected(self):
        key = pool.SECRETS/'shared.txt'
        key.parent.mkdir(parents=True)
        key.write_text('msy_' + 'x'*40)
        pool.write(pool.CONFIG, {'accounts': [{'id': name, 'key_file': 'shared.txt'} for name in ('a', 'b')]})
        with self.assertRaisesRegex(pool.Stop, 'DUPLICATE_ACCOUNT_OR_KEY'): pool.accounts()

    def test_duplicate_jobs_are_rejected(self):
        self.plan(2, jobs=[{'id': 'same', 'prompt': 'Chair'}]*2)
        with self.assertRaisesRegex(pool.Stop, 'DUPLICATE_JOB'): self.pipeline()

    def test_whole_account_cost_includes_stranded_credits(self):
        cost = pool.economy(30)
        self.assertEqual(cost['models_per_account'], 36)
        self.assertEqual(cost['credits_left_per_account'], 20)
        self.assertAlmostEqual(cost['cny_per_model_if_leftover_unused'], 1/3, places=6)

    def test_attach_checks_documented_task_type_and_prompt(self):
        response = {'id': 'task-0001', 'type': 'text-to-3d-preview', 'prompt': 'Chair'}
        pool.verify_task_identity(response, {'prompt': 'Chair'}, 'preview', {}, 'task-0001')
        with self.assertRaisesRegex(pool.Stop, 'TYPE_MISMATCH'):
            pool.verify_task_identity(response, {}, 'refine', {}, 'task-0001')
        with self.assertRaisesRegex(pool.Stop, 'PROMPT_MISMATCH'):
            pool.verify_task_identity(response, {'prompt': 'Table'}, 'preview', {}, 'task-0001')

    def test_attach_rejects_refine_from_another_preview(self):
        response = {'id': 'task-0002', 'type': 'text-to-3d-refine', 'preview_task_id': 'wrong'}
        with self.assertRaisesRegex(pool.Stop, 'PREVIEW_MISMATCH'):
            pool.verify_task_identity(response, {}, 'refine',
                {'stages': {'preview': {'task_id': 'task-0001'}}}, 'task-0002')


if __name__ == '__main__':
    unittest.main(verbosity=2)
