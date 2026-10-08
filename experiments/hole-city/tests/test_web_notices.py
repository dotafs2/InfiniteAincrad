"""Temp-directory distribution and refusal tests; no browser or network."""
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import package_web_notices as notices

HTML = '''<!doctype html><html lang="en"><head><title>Test</title></head><body>
<canvas id="canvas">Fallback</canvas><div id="status"><img id="status-splash">
<progress id="status-progress"></progress><div id="status-notice"></div></div>
<script>/* unchanged engine bootstrap */</script></body></html>'''
ENGINE = ("Godot Engine 4.7.2.stable.official.test\n\nMIT License\n"
          "Permission is hereby granted, free of charge, to any person obtaining a copy.\n"
          "THIRD-PARTY COPYRIGHT NOTICES\nComponent\nFiles: src/example.c\nCopyright: Example contributors\nLicense: MIT\n"
          "THIRD-PARTY LICENSE TEXTS\nMIT\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software.\n").encode()


class Links(HTMLParser):
    def __init__(self):
        super().__init__();self.anchors=[];self.links=[];self.language=None;self.viewport=None
    def handle_starttag(self, tag, attrs):
        attrs=dict(attrs)
        if tag=="a":self.anchors.append(attrs)
        if tag=="link":self.links.append(attrs)
        if tag=="html":self.language=attrs.get("lang")
        if tag=="meta" and attrs.get("name")=="viewport":self.viewport=attrs.get("content")


class WebNoticesTest(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.base=Path(self.temp.name);self.root=self.base/"source";self.root.mkdir()
        self.candidate=self.base/"candidate";self.candidate.mkdir()
        (self.candidate/"index.html").write_text(HTML)
        (self.candidate/"index.pck").write_bytes(b"unchanged pack")
        (self.candidate/"index.js").write_bytes(b"unchanged executable javascript")
        for source,_,_ in notices.SOURCE_NOTICES:
            p=self.root/source;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((source+"\nCopyright — exact UTF-8 notice\n").encode())
        (self.root/"tools").mkdir(exist_ok=True)
        (self.root/"tools/runtime_licenses.gd").write_text("exact license generator fixture")
        self.godot=self.base/"Godot";self.godot.write_bytes(b"exact engine fixture")
        self.root_patch=mock.patch.object(notices,"ROOT",self.root);self.root_patch.start();self.addCleanup(self.root_patch.stop)
    def snapshot(self):
        return {str(p.relative_to(self.candidate)):p.read_bytes() for p in self.candidate.rglob("*") if p.is_file()}
    def engine(self, command, **kwargs):
        out=Path(next(a.split("=",1)[1] for a in command if a.startswith("--license-out=")))
        self.assertTrue(out.is_absolute());self.assertIn("--test",command)
        self.assertEqual(kwargs["cwd"],self.root);self.assertEqual(kwargs["timeout"],45)
        self.assertTrue(Path(command[command.index("--log-file")+1]).is_absolute())
        out.write_bytes(ENGINE)
        return subprocess.CompletedProcess(command,0,"Godot Engine fixture\n")
    def install(self, engine=None):
        with mock.patch.object(notices.subprocess,"run",side_effect=engine or self.engine):
            return notices.install_notices(self.candidate,self.godot)
    def test_exact_bundle_and_all_manifest_hashes(self):
        original=self.snapshot();result=self.install()
        self.assertEqual(len(result),9)
        for source,name,_ in notices.SOURCE_NOTICES:
            self.assertEqual((self.root/source).read_bytes(),(self.candidate/"notices"/name).read_bytes())
        self.assertEqual((self.candidate/"notices/GODOT_LICENSES.txt").read_bytes(),ENGINE)
        for path,digest in result.items():self.assertEqual(hashlib.sha256((self.candidate/path).read_bytes()).hexdigest(),digest)
        manifest=json.loads((self.candidate/"notices/manifest.json").read_text())
        self.assertEqual(len(manifest["files"]),7)
        self.assertEqual(manifest["engine_sha256"],hashlib.sha256(self.godot.read_bytes()).hexdigest())
        for path,digest in manifest["files"].items():self.assertEqual(result[path],digest)
        self.assertEqual(original["index.pck"],(self.candidate/"index.pck").read_bytes())
        self.assertEqual(original["index.js"],(self.candidate/"index.js").read_bytes())
    def test_local_accessible_credits_and_loading_only_hook(self):
        self.install();page=Links();page.feed((self.candidate/"credits.html").read_text())
        self.assertEqual(page.language,"en");self.assertNotIn("user-scalable=no",page.viewport)
        self.assertEqual(len(page.anchors),8)
        for a in page.anchors:
            self.assertNotIn(":",a["href"]);self.assertTrue((self.candidate/a["href"]).is_file())
        index=(self.candidate/"index.html").read_text();links=Links();links.feed(index)
        self.assertEqual(links.links,[{"rel":"license","href":"credits.html"}])
        self.assertLess(index.index('</canvas>'),index.index(notices.LOAD_START))
        self.assertLess(index.index('<div id="status">'),index.index(notices.LOAD_START))
        self.assertLess(index.index(notices.LOAD_END),index.index('</div>\n<script>'))
        self.assertIn('min-height:44px',index);self.assertIn('rel="noopener"',index)
        self.assertIn('<script>/* unchanged engine bootstrap */</script>',index)
    def test_idempotent_exactly_once(self):
        first=self.install();snapshot=self.snapshot();second=self.install()
        self.assertEqual(first,second);self.assertEqual(snapshot,self.snapshot())
        index=(self.candidate/"index.html").read_text()
        self.assertEqual(index.count(notices.HEAD_START),1);self.assertEqual(index.count(notices.LOAD_START),1)
    def test_missing_and_unsafe_template_no_mutation(self):
        bad=[HTML.replace('<div id="status-notice"></div>',""),HTML.replace('</head>',""),
             HTML.replace('<div id="status">','<div id="status"></div>'),
             HTML.replace('</head>',notices.HEAD_START+'</head>'),
             HTML.replace('<div id="status">','<div id="status"><div id="status">')]
        for text in bad:
            with self.subTest(text=text):
                (self.candidate/"index.html").write_text(text);before=self.snapshot()
                with mock.patch.object(notices.subprocess,"run") as run:
                    with self.assertRaises(ValueError):notices.install_notices(self.candidate,self.godot)
                    run.assert_not_called()
                self.assertEqual(before,self.snapshot())
    def test_missing_or_empty_source_no_mutation(self):
        path=self.root/notices.SOURCE_NOTICES[-1][0];path.unlink();before=self.snapshot()
        with self.assertRaises(FileNotFoundError):self.install()
        self.assertEqual(before,self.snapshot());path.write_bytes(b" \n")
        with self.assertRaises(ValueError):self.install()
        self.assertEqual(before,self.snapshot())
    def test_symlink_output_rejected_without_following_it(self):
        outside=self.base/"outside";outside.write_text("never change")
        (self.candidate/"credits.html").symlink_to(outside)
        with self.assertRaises(ValueError):self.install()
        self.assertEqual(outside.read_text(),"never change")
    def test_engine_exit_and_zero_exit_diagnostics_rejected(self):
        cases=[(1,"ordinary failure"),(0,"ERROR: arbitrary engine error\n"),
               (0," \x1b[31mSCRIPT ERROR: failed\x1b[0m\n"),(0,"SHADER ERROR: failed\n"),(0,"FATAL: failed\n")]
        for code,text in cases:
            with self.subTest(text=text):
                before=self.snapshot()
                def fail(command,**kwargs):
                    self.engine(command,**kwargs);return subprocess.CompletedProcess(command,code,text)
                with self.assertRaises(RuntimeError):self.install(fail)
                self.assertEqual(before,self.snapshot())
    def test_engine_log_diagnostics_rejected(self):
        before=self.snapshot()
        def fail(command,**kwargs):
            result=self.engine(command,**kwargs)
            Path(command[command.index('--log-file')+1]).write_text('ERROR: hidden engine log failure\n')
            return result
        with self.assertRaises(RuntimeError):self.install(fail)
        self.assertEqual(before,self.snapshot())
    def test_only_exact_known_certificate_diagnostic_allowed(self):
        def known(command,**kwargs):
            result=self.engine(command,**kwargs)
            result.stdout='ERROR: Condition "ret != noErr" is true. Returning: ""\n   at: get_system_ca_certificates (platform/macos/os_macos.mm:1035)\n'
            return result
        self.install(known)
        before=self.snapshot()
        def unrelated(command,**kwargs):
            result=known(command,**kwargs);result.stdout=result.stdout.replace('get_system_ca_certificates','unrelated_function');return result
        with self.assertRaises(RuntimeError):self.install(unrelated)
        self.assertEqual(before,self.snapshot())
    def test_timeout_no_mutation(self):
        before=self.snapshot()
        with self.assertRaises(RuntimeError):
            self.install(lambda *a,**k:(_ for _ in ()).throw(subprocess.TimeoutExpired(a[0],45)))
        self.assertEqual(before,self.snapshot())
    def test_missing_truncated_or_invalid_engine_notice(self):
        for data in [None,b"",b"Godot Engine fixture\n",ENGINE.split(b'THIRD-PARTY LICENSE TEXTS')[0]+b'THIRD-PARTY LICENSE TEXTS\n']:
            with self.subTest(data=data):
                before=self.snapshot()
                def invalid(command,**kwargs):
                    result=self.engine(command,**kwargs);path=Path(next(a.split('=',1)[1] for a in command if a.startswith('--license-out=')))
                    if data is None:path.unlink()
                    else:path.write_bytes(data)
                    return result
                with self.assertRaises(RuntimeError):self.install(invalid)
                self.assertEqual(before,self.snapshot())
    def test_source_and_engine_change_are_rejected(self):
        for target in [self.root/'LICENSE',self.root/'tools/runtime_licenses.gd',self.godot]:
            with self.subTest(target=target):
                before=self.snapshot();original=target.read_bytes()
                def mutate(command,**kwargs):
                    result=self.engine(command,**kwargs);target.write_bytes(original+b' changed');return result
                with self.assertRaises(RuntimeError):self.install(mutate)
                self.assertEqual(before,self.snapshot());target.write_bytes(original)
    def test_candidate_index_race_rejected(self):
        def mutate(command,**kwargs):
            result=self.engine(command,**kwargs);(self.candidate/'index.html').write_text('other writer');return result
        with self.assertRaises(RuntimeError):self.install(mutate)
        self.assertEqual((self.candidate/'index.html').read_text(),'other writer')
        self.assertFalse((self.candidate/'notices').exists());self.assertFalse((self.candidate/'credits.html').exists())
    def test_each_commit_failure_rolls_back_old_bundle(self):
        self.install();before=self.snapshot();replace=notices.os.replace
        for fail_at in range(1,7):
            with self.subTest(fail_at=fail_at):
                calls=0
                def fail_once(a,b):
                    nonlocal calls
                    calls+=1
                    if calls==fail_at:raise OSError('injected one-time rename failure')
                    return replace(a,b)
                with mock.patch.object(notices.os,'replace',side_effect=fail_once):
                    with self.assertRaises(OSError):self.install()
                self.assertEqual(before,self.snapshot())
    def test_first_install_failure_leaves_no_partial_notices(self):
        before=self.snapshot();replace=notices.os.replace;calls=0
        def fail_once(a,b):
            nonlocal calls
            calls+=1
            if calls==3:raise OSError('injected index backup failure')
            return replace(a,b)
        with mock.patch.object(notices.os,'replace',side_effect=fail_once):
            with self.assertRaises(OSError):self.install()
        self.assertEqual(before,self.snapshot())


if __name__ == '__main__':
    unittest.main(verbosity=2)
