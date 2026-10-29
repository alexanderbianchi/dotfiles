"""Offline tests for Neovim provisioning; no real plugins or tools are installed."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NvimInstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name) / 'home'
        self.home.mkdir()
        self.root = self.home / 'source'
        shutil.copytree(ROOT / '.config/nvim', self.root / '.config/nvim')
        shutil.copytree(ROOT / 'scripts', self.root / 'scripts')
        shutil.copy2(ROOT / 'install.sh', self.root / 'install.sh')
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.env = {**os.environ, 'HOME': str(self.home),
                    'PATH': f'{self.bin}:{os.environ["PATH"]}',
                    'XDG_DATA_HOME': str(self.home / 'data'),
                    'XDG_STATE_HOME': str(self.home / 'state'),
                    'NVIM_APPNAME': 'nvim', 'CALL_LOG': str(self.home / 'calls')}
        self.lock = self.root / '.config/nvim/lazy-lock.json'
        self.original = self.lock.read_bytes()
        self.pin = json.loads(self.original)['lazy.nvim']['commit']
        self.env['MANAGER_PIN'] = self.pin
        manager = self.home / 'data/nvim/lazy/lazy.nvim'
        (manager / '.git').mkdir(parents=True)
        for tool in ['go', 'java', 'make', 'cc']:
            self.fake(tool, '#!/bin/sh\nexit 0\n')
        self.fake('git', '''#!/bin/sh
case "$*" in
  *'status --porcelain'*)
    [ "${GENERATED_TAGS:-0}" = 0 ] || echo '?? doc/tags'
    [ "${DIRTY:-0}" = 0 ] || echo ' M user-edit.lua'
    ;;
  *'rev-parse HEAD'*) echo "$MANAGER_PIN" ;;
  *) echo "git $*" >> "$CALL_LOG" ;;
esac
''')
        self.fake('nvim', '''#!/usr/bin/env python3
import os, pathlib, sys
phase = os.environ['DOTFILES_NVIM_PHASE']
with open(os.environ['CALL_LOG'], 'a') as log:
    log.write(phase + '\\n')
lock = pathlib.Path(os.environ['DOTFILES_NVIM_LOCKFILE'])
assert lock.read_bytes() == (pathlib.Path(os.environ['DOTFILES_NVIM_ROOT']) / '.config/nvim/lazy-lock.json').read_bytes()
lock.write_text('generated lock')
if os.environ.get('FAIL_PHASE') == phase:
    sys.exit(23)
if not os.environ.get('NO_COMPLETION'):
    pathlib.Path(os.environ['DOTFILES_NVIM_SUCCESSFILE']).write_text('verified')
''')

    def fake(self, name, content):
        p = self.bin / name
        p.write_text(content)
        p.chmod(0o755)

    def run_install(self, **env):
        return subprocess.run(['bash', str(self.root / 'install.sh'), '--nvim-only'],
                              env={**self.env, **env}, capture_output=True, text=True)

    def calls(self):
        p = self.home / 'calls'
        return p.read_text().splitlines() if p.exists() else []

    def test_repeatable_and_does_not_dirty_source_or_run_pi(self):
        for _ in range(2):
            result = self.run_install()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.lock.read_bytes(), self.original)
        self.assertEqual(self.calls(), ['plugins', 'verify', 'plugins', 'verify'])
        self.assertFalse((self.home / 'data/nvim/.dotfiles-install-lock').exists())
        self.assertFalse((self.home / '.zshrc').exists())
        self.assertEqual((self.home / '.config/nvim').resolve(), (self.root / '.config/nvim').resolve())

    def test_failures_propagate_preserve_lock_and_allow_retry(self):
        for phase in ['plugins', 'verify']:
            result = self.run_install(FAIL_PHASE=phase)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('provisioning failed', result.stderr)
            self.assertEqual(self.lock.read_bytes(), self.original)
            self.assertFalse((self.home / 'data/nvim/.dotfiles-install-lock').exists())
        self.assertEqual(self.run_install().returncode, 0)

    def test_zero_exit_without_completed_checks_is_failure(self):
        result = self.run_install(NO_COMPLETION='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('checks did not complete', result.stderr)
        self.assertEqual(self.calls(), ['plugins'])

    def test_refuses_local_plugin_edits(self):
        result = self.run_install(DIRTY='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Refusing to overwrite Neovim plugin edits', result.stderr)
        self.assertEqual(self.calls(), [])

    def test_generated_help_tags_do_not_block_repeat_installs(self):
        result = self.run_install(GENERATED_TAGS='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_install(GENERATED_TAGS='1', DIRTY='1')
        self.assertNotEqual(result.returncode, 0)

    def test_neovim_only_preserves_existing_config(self):
        config = self.home / '.config/nvim'
        config.mkdir(parents=True)
        (config / 'init.lua').write_text('-- my old config')
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        backups = self.home / '.local/state/dotfiles/backups'
        self.assertTrue(any(p.read_text() == '-- my old config' for p in backups.glob('*/nvim/init.lua')))

    def test_rejects_invalid_plugin_pins_before_git(self):
        self.lock.write_text('{"lazy.nvim":{"commit":"invalid"}}')
        result = self.run_install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Invalid plugin pin', result.stderr)
        self.assertEqual(self.calls(), [])

    def test_refuses_concurrent_provisioning(self):
        (self.home / 'data/nvim/.dotfiles-install-lock').mkdir()
        result = self.run_install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('already running', result.stderr)
        self.assertEqual(self.calls(), [])

    def test_system_install_runs_editor_bootstrap_and_propagates_failure(self):
        for name in ['apt-get', 'tic', 'mosh', 'delta', 'claude', 'cargo', 'claude-kanban', 'fd']:
            self.fake(name, '#!/bin/sh\nexit 0\n')
        self.fake('sudo', '#!/bin/sh\nexec "$@"\n')
        self.fake('uname', '#!/bin/sh\necho Linux\n')
        self.fake('nvim', '#!/bin/sh\nexit 0\n')
        for directory in ['.oh-my-zsh', '.local/share/tmux/plugins/tpm', '.local/share/tmux/plugins/tmux-fzf-url']:
            (self.home / directory).mkdir(parents=True, exist_ok=True)
        bootstrap = self.root / 'scripts/install-nvim.sh'
        bootstrap.write_text('#!/bin/sh\necho bootstrap >> "$CALL_LOG"\nexit "${BOOTSTRAP_EXIT:-0}"\n')
        for code in [0, 29]:
            result = subprocess.run(['bash', str(self.root / 'scripts/install-system.sh')],
                                    env={**self.env, 'BOOTSTRAP_EXIT': str(code)}, capture_output=True, text=True)
            self.assertEqual(result.returncode, code, result.stderr)
        self.assertEqual(self.calls(), ['bootstrap', 'bootstrap'])


if __name__ == '__main__':
    unittest.main()
