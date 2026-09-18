"""Offline launch regressions: stale caches never bypass preparation failures."""
import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import play_pcg_trial as preview


class PreviewPreparationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        # Simulate a previous checkout's outputs: existence alone proves nothing.
        dll = self.root / 'game/.godot/mono/temp/bin/Debug/InfiniteAincrad.dll'
        dll.parent.mkdir(parents=True)
        dll.write_bytes(b'old checkout')
        (self.root / 'game/.godot/imported').mkdir()
        self.godot = self.root / 'godot.exe'
        self.godot.write_bytes(b'fixture')
        self.source = self.root / 'source.json'
        self.source.write_text(json.dumps({
            'world_id': 'fixture:offline-preview',
            'godot': {'spatial_layout': {'id': 'first-floor-market-quarter-v1'}},
        }), encoding='utf-8')
        self.before = self.source.read_bytes()
        self.enterContext(patch.object(preview, 'ROOT', self.root))
        self.enterContext(patch.object(preview.shutil, 'which', return_value='dotnet.exe'))

    def launch(self, prepare_only=False):
        args = ['preview', '--save', str(self.source), '--godot', str(self.godot)]
        if prepare_only:
            args.append('--prepare-only')
        with patch.object(sys, 'argv', args), contextlib.redirect_stdout(io.StringIO()):
            return preview.main()

    def assert_no_preview_copy(self):
        self.assertEqual(self.source.read_bytes(), self.before)
        self.assertEqual(list((self.root / 'private').glob('*/visit-*/world.json')), [])

    def test_existing_caches_still_refresh_before_preparing_copy(self):
        phases = []

        def prepare(command, **kwargs):
            phases.append('build' if 'build' in command else 'import')
            self.assert_no_preview_copy()
            if phases[-1] == 'build':
                self.assertIn('--disable-build-servers', command)
            return 0

        with patch.object(preview.subprocess, 'call', side_effect=prepare), \
                patch.object(preview, 'WindowsProcessTree', side_effect=AssertionError('Unexpected preview launch')) as window:
            self.assertEqual(self.launch(prepare_only=True), 0)
        self.assertEqual(phases, ['build', 'import'])
        window.assert_not_called()
        copies = list((self.root / 'private').glob('*/visit-*/world.json'))
        self.assertEqual(len(copies), 1)
        self.assertEqual(copies[0].read_bytes(), self.before)
        self.assertEqual(self.source.read_bytes(), self.before)

    def test_failed_build_never_imports_copies_or_opens_world(self):
        with patch.object(preview.subprocess, 'call', return_value=1) as run, \
                patch.object(preview, 'WindowsProcessTree', side_effect=AssertionError('Unexpected preview launch')) as window:
            with self.assertRaisesRegex(RuntimeError, 'C# build failed'):
                self.launch()
        self.assertEqual(run.call_count, 1)
        window.assert_not_called()
        self.assert_no_preview_copy()

    def test_failed_import_never_copies_or_opens_world(self):
        with patch.object(preview.subprocess, 'call', side_effect=[0, 1]), \
                patch.object(preview, 'WindowsProcessTree', side_effect=AssertionError('Unexpected preview launch')) as window:
            with self.assertRaisesRegex(RuntimeError, 'Godot import failed'):
                self.launch()
        window.assert_not_called()
        self.assert_no_preview_copy()

    def test_missing_sdk_cannot_silently_use_old_binary(self):
        with patch.object(preview.shutil, 'which', return_value=None), \
                patch.object(preview.subprocess, 'call') as run, \
                patch.object(preview, 'WindowsProcessTree', side_effect=AssertionError('Unexpected preview launch')):
            with self.assertRaises(FileNotFoundError):
                self.launch()
        run.assert_not_called()
        self.assert_no_preview_copy()


if __name__ == '__main__':
    unittest.main()
