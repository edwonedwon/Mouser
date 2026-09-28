import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.install_macos_app import install


class MacInstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = self.root / 'source.app'
        exe = self.source / 'Contents/MacOS/Mouser'
        exe.parent.mkdir(parents=True)
        exe.write_text('new')
        self.dest = self.root / 'installed.app'
        self.dest.mkdir()
        (self.dest / 'old').write_text('keep')
        self.calls = []
        self.fail = None

    def run_command(self, args, **kwargs):
        self.calls.append(args)
        if args[0] == self.fail:
            raise subprocess.CalledProcessError(1, args)
        if args[0] == 'ditto':
            shutil.copytree(args[1], args[2])

    def test_copy_and_verify_failures_preserve_installed_app_without_stopping_it(self):
        for command in ('ditto', 'codesign'):
            self.fail = command
            self.calls.clear()
            with self.assertRaises(subprocess.CalledProcessError):
                install(self.source, self.dest, run=self.run_command)
            self.assertTrue((self.dest / 'old').exists())
            self.assertFalse(any(c[0] in ('pkill', 'launchctl') for c in self.calls))

    def test_success_verifies_before_stopping_and_never_resets_tcc(self):
        with patch('tools.install_macos_app.Path.home', return_value=self.root):
            install(self.source, self.dest, run=self.run_command)
        self.assertEqual((self.dest / 'Contents/MacOS/Mouser').read_text(), 'new')
        commands = [c[0] for c in self.calls]
        self.assertLess(commands.index('codesign'), commands.index('pkill'))
        self.assertNotIn('tccutil', commands)
        self.assertEqual(commands[-1], 'open')

    def test_replace_failure_rolls_back_previous_app(self):
        rename = Path.rename

        def failing_rename(path, target):
            if path.name == 'Mouser.app':
                raise OSError('replace failed')
            return rename(path, target)

        with patch.object(Path, 'rename', failing_rename):
            with self.assertRaisesRegex(OSError, 'replace failed'):
                install(self.source, self.dest, run=self.run_command)
        self.assertTrue((self.dest / 'old').exists())
        self.assertFalse(any(c[0] == 'open' for c in self.calls))
