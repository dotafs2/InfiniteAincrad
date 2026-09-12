"""Windows-only fake parent/child lifetime checks. No Godot engine or model API."""
import ctypes
from ctypes import wintypes as W
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

if os.name == 'nt':
    from owned_windows_job import WindowsProcessTree, _k

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'tmp/gpt6-sprint/resident-memory/process-tree/tests'
FIXTURE = '''import json, os, pathlib, subprocess, sys, time
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
info = pathlib.Path(sys.argv[sys.argv.index('--info') + 1])
mode = sys.argv[sys.argv.index('--mode') + 1]
duration = 0.4 if mode in ('normal', 'orphan', 'child-failure') else 120
child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(' + str(duration) + '); raise SystemExit(' + ('7' if mode == 'child-failure' else '0') + ')'], creationflags=subprocess.CREATE_NO_WINDOW)
info.write_text(json.dumps({'parent': os.getpid(), 'child': child.pid}))
print('任务持有的假进程', flush=True)
if mode != 'orphan':
    child.wait()
'''


@unittest.skipUnless(os.name == 'nt', 'Windows job containment only')
class OwnedProcessTests(unittest.TestCase):
    def setUp(self):
        OUT.mkdir(parents=True, exist_ok=True)
        self.folder = Path(tempfile.mkdtemp(prefix=self._testMethodName + '-', dir=OUT))
        self.script = self.folder / 'fake_parent.py'
        self.script.write_text(FIXTURE, encoding='utf-8')

    def command(self, mode):
        return [sys.executable, str(self.script), '--mode', mode, '--info', str(self.folder / 'members.json')]

    def assert_gone(self, members):
        # Check each stable PID+creation-time identity. Never terminate a PID here.
        deadline = time.monotonic() + 3
        pending = list(members)
        while pending and time.monotonic() < deadline:
            survivors = []
            for member in pending:
                handle = _k.OpenProcess(0x100000 | 0x1000, False, member['pid'])
                if not handle:
                    continue
                try:
                    times = [W.FILETIME() for _ in range(4)]
                    self.assertTrue(_k.GetProcessTimes(handle, *(ctypes.byref(value) for value in times)))
                    created = (times[0].dwHighDateTime << 32) | times[0].dwLowDateTime
                    if created == member['creation_time_windows_100ns'] and _k.WaitForSingleObject(handle, 0) == 258:
                        survivors.append(member)
                finally:
                    _k.CloseHandle(handle)
            pending = survivors
            if pending:
                time.sleep(0.02)
        self.assertEqual([], pending, 'No owned process identity survives cleanup')

    def wait_for_child(self, tree):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            state = tree.snapshot()
            if (self.folder / 'members.json').exists() and len(state['observed_members']) >= 2:
                return state
            time.sleep(0.02)
        self.fail('Fake parent did not spawn its child')

    def test_normal_child_exit(self):
        with WindowsProcessTree(self.command('normal'), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) as tree:
            self.assertEqual(0, tree.wait(5))
            state = tree.snapshot()
            self.assertTrue(state['all_members_exited'])
            self.assertGreaterEqual(state['total_assigned_processes'], 2)
            self.assertTrue(all(member['exit_code'] == 0 for member in state['observed_members']))
        self.assert_gone(state['observed_members'])

    def test_child_outlives_wrapper(self):
        started = time.monotonic()
        with WindowsProcessTree(self.command('orphan'), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) as tree:
            self.assertEqual(0, tree.wait(5))
            state = tree.snapshot()
            self.assertTrue(state['all_members_exited'])
        self.assertGreater(time.monotonic() - started, 0.35)
        self.assert_gone(state['observed_members'])

    def test_child_failure_is_not_wrapper_success(self):
        with WindowsProcessTree(self.command('child-failure'), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) as tree:
            self.assertEqual(0, tree.wait(5), 'API returns the wrapper exit explicitly')
            state = tree.snapshot()
            self.assertTrue(state['all_members_exited'])
            self.assertTrue(any(member['exit_code'] == 7 for member in state['observed_members']))
            self.assertTrue(state['observed_nonzero_exits'], 'Wrapper zero is not a claim that every member succeeded')
        self.assert_gone(state['observed_members'])

    def test_timeout_tree_and_unrelated_survives(self):
        unrelated = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(120)'], creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            with WindowsProcessTree(self.command('timeout'), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) as tree:
                self.wait_for_child(tree)
                with self.assertRaises(subprocess.TimeoutExpired):
                    tree.wait(0.15)
                tree.terminate(124)
                state = tree.snapshot()
                self.assertTrue(state['all_members_exited'])
                self.assertNotIn(unrelated.pid, [member['pid'] for member in state['observed_members']])
            self.assert_gone(state['observed_members'])
            self.assertIsNone(unrelated.poll(), 'Unrelated process is not in the owned job')
        finally:
            unrelated.terminate()  # Popen owns the original native process handle.
            unrelated.wait(timeout=5)

    def test_interrupt_callback_cleanup(self):
        members = []
        def interrupt(state):
            members[:] = state['observed_members']
            if len(members) >= 2:
                raise KeyboardInterrupt('test interrupt')
        with self.assertRaisesRegex(KeyboardInterrupt, 'test interrupt'):
            with WindowsProcessTree(self.command('timeout'), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) as tree:
                tree.wait(5, on_poll=interrupt)
        self.assert_gone(members)

    def test_cleanup_error_preserves_callback_error(self):
        with self.assertRaisesRegex(RuntimeError, 'original callback error'):
            with WindowsProcessTree(self.command('timeout'), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) as tree:
                members = self.wait_for_child(tree)['observed_members']
                with mock.patch.object(tree, 'terminate', side_effect=OSError('injected cleanup error')):
                    # Keep the patch active through the context manager's exit.
                    try:
                        raise RuntimeError('original callback error')
                    except RuntimeError:
                        tree.__exit__(*sys.exc_info())
                        raise
        self.assert_gone(members)

    def test_resume_failure_is_fail_closed(self):
        observed = []
        def fail_resume(tree):
            observed.extend(tree.snapshot()['observed_members'])
            raise RuntimeError('injected resume failure')
        with mock.patch.object(WindowsProcessTree, '_resume_primary_thread', fail_resume):
            with self.assertRaisesRegex(RuntimeError, 'injected resume failure'):
                WindowsProcessTree(self.command('timeout'), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.assertFalse((self.folder / 'members.json').exists(), 'Suspended wrapper never executes')
        self.assert_gone(observed)

    def test_assignment_failure_is_fail_closed(self):
        captured = []
        original_popen = subprocess.Popen
        def capture_process(*args, **kwargs):
            process = original_popen(*args, **kwargs)
            captured.append(process)
            return process
        # Failed assignment means the suspended wrapper must be killed directly,
        # even though it never became a job member and must never run its script.
        with mock.patch.object(_k, 'AssignProcessToJobObject', return_value=False), mock.patch('owned_windows_job.subprocess.Popen', side_effect=capture_process):
            with self.assertRaises(OSError):
                WindowsProcessTree(self.command('timeout'), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.assertEqual(1, len(captured))
        self.assertIsNotNone(captured[0].poll(), 'Exact suspended Popen handle was terminated on failed assignment')
        self.assertFalse((self.folder / 'members.json').exists())

    def test_runner_hard_exit_closes_kernel_job(self):
        marker = self.folder / 'controller-members.json'
        controller = self.folder / 'controller.py'
        controller.write_text("import json, pathlib, subprocess, sys, time\n"
            "sys.path.insert(0, sys.argv[1])\nfrom owned_windows_job import WindowsProcessTree\n"
            "tree=WindowsProcessTree(sys.argv[3:], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n"
            "while len(tree.snapshot()['observed_members']) < 2: time.sleep(0.02)\n"
            "pathlib.Path(sys.argv[2]).write_text(json.dumps(tree.snapshot()))\ntime.sleep(120)\n", encoding='utf-8')
        process = subprocess.Popen([sys.executable, str(controller), str(ROOT / 'tools'), str(marker)] + self.command('timeout'), creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            deadline = time.monotonic() + 4
            while not marker.exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(marker.exists())
            members = json.loads(marker.read_text())['observed_members']
            process.kill()  # Only this test's original Popen handle, bypassing Python finally.
            process.wait(timeout=5)
            self.assert_gone(members)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)

    def test_real_runner_timeout_metadata_utf8(self):
        command_file = self.folder / 'fake_godot.cmd'
        command_file.write_text('@"' + sys.executable + '" "' + str(self.script) + '" %*\n', encoding='utf-8')
        command = [sys.executable, str(ROOT / 'tools/run_godot.py'), '--godot', str(command_file), '--name', 'fake-timeout',
                   '--timeout', '1', '--out', str(self.folder), '--', '--mode', 'timeout', '--info', str(self.folder / 'members.json')]
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding='utf-8', timeout=10)
        self.assertEqual(124, result.returncode, result.stdout + result.stderr)
        record = json.loads((self.folder / 'fake-timeout.process.json').read_text(encoding='utf-8'))
        self.assertEqual('terminated_owned_process_after_timeout', record['status'])
        self.assertTrue(record['process_tree']['all_members_exited'])
        self.assertGreaterEqual(record['process_tree']['total_assigned_processes'], 2)
        self.assert_gone(record['process_tree']['observed_members'])
        self.assertIn('任务持有的假进程', result.stdout)

    def test_real_runner_observed_child_failure_overrides_wrapper_zero(self):
        command_file = self.folder / 'fake_godot.cmd'
        command_file.write_text('@"' + sys.executable + '" "' + str(self.script) + '" %*\n@exit /b 0\n', encoding='utf-8')
        for mode, expected_code, expected_source in (
            ('normal', 0, 'wrapper'), ('child-failure', 1, 'observed_member_failure')
        ):
            with self.subTest(mode=mode):
                command = [sys.executable, str(ROOT / 'tools/run_godot.py'), '--godot', str(command_file), '--name', mode,
                           '--timeout', '5', '--out', str(self.folder), '--', '--mode', mode, '--info', str(self.folder / 'members.json')]
                result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding='utf-8', timeout=10)
                self.assertEqual(expected_code, result.returncode, result.stdout + result.stderr)
                record = json.loads((self.folder / (mode + '.process.json')).read_text(encoding='utf-8'))
                self.assertEqual(0, record['wrapper_exit_code'])
                self.assertEqual(expected_code, record['exit_code'])
                self.assertEqual(expected_source, record['exit_code_source'])
                self.assertTrue(record['process_tree']['all_members_exited'])
                if mode == 'child-failure':
                    self.assertTrue(any(member['exit_code'] == 7 for member in record['process_tree']['observed_members']))
                else:
                    self.assertFalse(record['process_tree']['observed_nonzero_exits'])
                self.assert_gone(record['process_tree']['observed_members'])


if __name__ == '__main__':
    unittest.main()
