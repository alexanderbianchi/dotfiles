"""Offline provisioning tests using temporary homes and mocked tools."""
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name) / 'home'
        self.home.mkdir()
        self.bin = self.home / 'mock-bin'
        self.bin.mkdir()
        self.agent = self.home / '.pi/agent'
        self.env = {**os.environ, 'HOME': str(self.home),
                    'PI_CODING_AGENT_DIR': str(self.agent),
                    'PATH': f'{self.bin}:{os.environ["PATH"]}',
                    'CALL_LOG': str(self.home / 'calls')}

    def fake(self, name, content):
        p = self.bin / name
        p.write_text(content)
        p.chmod(0o755)

    def run_install(self, mode, root=ROOT, **env):
        return subprocess.run(['bash', str(root / 'install.sh'), mode],
                              env={**self.env, **env}, capture_output=True, text=True)

    def test_links_are_repeatable_and_preserve_credentials_and_conflicts(self):
        (self.home / '.zshrc').write_text('my shell')
        gh = self.home / '.config/gh'
        gh.mkdir(parents=True)
        (gh / 'hosts.yml').write_text('private credentials')
        (gh / 'config.yml').write_text('old gh settings')
        self.agent.mkdir(parents=True)
        (self.agent / 'auth.json').write_text('private auth')
        (self.agent / 'sessions').mkdir()
        (self.agent / 'sessions/local.jsonl').write_text('private session')
        for _ in range(2):
            result = self.run_install('--links-only')
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((gh / 'hosts.yml').read_text(), 'private credentials')
        self.assertEqual((self.agent / 'auth.json').read_text(), 'private auth')
        self.assertEqual((self.agent / 'sessions/local.jsonl').read_text(), 'private session')
        self.assertEqual((self.home / '.zshrc').resolve(), ROOT / '.zshrc')
        backups = list((self.home / '.local/state/dotfiles/backups').glob('*'))
        self.assertEqual(len(backups), 2)
        self.assertEqual(sorted(p.read_text() for b in backups for p in b.iterdir()),
                         ['my shell', 'old gh settings'])

    def test_works_through_shared_repository_symlink(self):
        (self.home / 'dotfiles').symlink_to(ROOT, target_is_directory=True)
        (self.home / '.zshrc').symlink_to('/missing/old-file')
        result = self.run_install('--links-only', root=self.home / 'dotfiles')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / '.zshrc').resolve(), ROOT / '.zshrc')
        backups = (self.home / '.local/state/dotfiles/backups').iterdir()
        self.assertTrue(any((backup / '.zshrc').is_symlink() for backup in backups))

    def prepare_pi(self):
        package = self.agent / 'git/github.com/alexanderbianchi/pi-config'
        (package / '.git').mkdir(parents=True)
        (package / 'scripts').mkdir()
        bootstrap = package / 'scripts/bootstrap.sh'
        bootstrap.write_text('#!/bin/sh\necho bootstrap >> "$CALL_LOG"\n')
        bootstrap.chmod(0o755)
        self.fake('pi', '''#!/bin/sh
if [ "$1" = --version ]; then echo "${MOCK_PI_VERSION:-0.85.1}"; exit; fi
printf 'pi %s\n' "$*" >> "$CALL_LOG"
[ "${FAIL_PI:-0}" = 0 ] || exit 17
''')
        self.fake('npm', '''#!/bin/sh
printf 'npm %s\n' "$*" >> "$CALL_LOG"
''')
        self.fake('git', '''#!/bin/sh
case "$*" in
  *'status --porcelain'*) [ "${DIRTY:-0}" = 0 ] || echo ' M local.ts' ;;
  *) echo 'Unexpected git command' >&2; exit 1 ;;
esac
''')

    def calls(self):
        log = self.home / 'calls'
        return log.read_text() if log.exists() else ''

    def test_pi_only_installs_package_and_runs_extension_bootstrap(self):
        self.prepare_pi()
        result = self.run_install('--pi-only')
        self.assertEqual(result.returncode, 0, result.stderr)
        source = (ROOT / 'config/pi-package.txt').read_text().strip()
        self.assertIn(f'pi install {source}', self.calls())
        self.assertIn('bootstrap', self.calls())
        self.assertNotIn('npm ', self.calls())
        self.assertFalse((self.home / '.zshrc').exists())

    def test_upgrades_old_cli_but_keeps_newer_cli(self):
        self.prepare_pi()
        result = self.run_install('--pi-only', MOCK_PI_VERSION='0.82.1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('@earendil-works/pi-coding-agent@0.85.1', self.calls())
        (self.home / 'calls').unlink()
        result = self.run_install('--pi-only', MOCK_PI_VERSION='1.0.0')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('npm ', self.calls())

    def test_pi_failure_propagates(self):
        self.prepare_pi()
        result = self.run_install('--pi-only', FAIL_PI='1')
        self.assertEqual(result.returncode, 17)
        self.assertNotIn('bootstrap', self.calls())
        self.assertNotIn('Dotfiles installed.', result.stdout)

    def test_dirty_personal_package_is_not_reset(self):
        self.prepare_pi()
        result = self.run_install('--pi-only', DIRTY='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Refusing to overwrite', result.stderr)
        self.assertEqual(self.calls(), '')

    def test_default_install_runs_system_then_pi_then_work(self):
        copy = self.home / 'dotfiles'
        shutil.copytree(ROOT / 'scripts', copy / 'scripts')
        shutil.copy2(ROOT / 'install.sh', copy / 'install.sh')
        for name in ['system', 'pi', 'work']:
            p = copy / f'scripts/install-{name}.sh'
            p.write_text(f'#!/bin/sh\necho {name} >> "$CALL_LOG"\n')
            p.chmod(0o755)
        result = self.run_install('', root=copy)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls().splitlines(), ['system', 'pi', 'work'])

    def test_stable_workspace_ssh_socket_is_used(self):
        self.prepare_pi()
        self.fake('pi', '''#!/bin/sh
if [ "$1" = --version ]; then echo 0.85.1; exit; fi
printf '%s' "$SSH_AUTH_SOCK" >> "$CALL_LOG"
''')
        sock = self.home / '.ssh/ssh_auth_sock'
        sock.parent.mkdir()
        # macOS Unix sockets have short path limits; the test temp prefix is short.
        if len(str(sock)) >= 104:
            self.skipTest('temporary socket path exceeds platform limit')
        with socket.socket(socket.AF_UNIX) as agent:
            agent.bind(str(sock))
            result = self.run_install('--pi-only', SSH_AUTH_SOCK='/stale/socket')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.calls().startswith(str(sock)))


if __name__ == '__main__':
    unittest.main()
