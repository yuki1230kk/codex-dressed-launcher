"""Exercise the real adapter against fake dependency functions; never open a client."""
import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

class AdapterTests(unittest.TestCase):
    def run_case(self, *, running=False, switch=0, launch=0, endpoint=0, verify=0):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            scripts = root / 'engine' / 'scripts'
            scripts.mkdir(parents=True)
            calls = root / 'calls'
            calls.touch()
            node = root / 'node'
            node.write_text('#!/bin/bash\necho verify >> "$CALLS"\nexit "$VERIFY"\n')
            node.chmod(0o700)
            opener = root / 'open'
            opener.write_text('#!/bin/bash\necho launch >> "$CALLS"\nexit "$LAUNCH"\n')
            opener.chmod(0o700)
            (scripts / 'common-macos.sh').write_text('''
record() { echo "$1" >> "$CALLS"; }
discover_codex_app() { :; }
require_signed_node_runtime() { :; }
codex_is_running() { [ "$RUNNING" = true ]; }
verify_macos_app_signature() { :; }
ensure_state_root() { :; }
stop_recorded_injector() { record stop_injector; }
sync_appearance_pin() { :; }
select_available_port() { echo 9341; }
wait_for_cdp() { record endpoint; return "$ENDPOINT"; }
launch_injector_daemon() { record injector; echo 321; }
process_started_at() { echo timestamp; }
codex_main_pids() { echo 123; }
write_state() { record state; }
mark_state_active() { record active; }
mark_state_stale() { record stale; }
STATE_PATH="$TMP_CASE/nonexistent-state"
THEME_DIR="$TMP_CASE/theme"
CODEX_BUNDLE="$TMP_CASE/Client.app"
NODE="$TMP_CASE/node"
INJECTOR="$TMP_CASE/injector.mjs"
''')
            switcher = scripts / 'switch-theme-macos.sh'
            switcher.write_text('#!/bin/bash\necho switch >> "$CALLS"\nexit "$SWITCH"\n')
            switcher.chmod(0o700)
            adapter = root / 'adapter.sh'
            adapter.write_text((ROOT / 'macos/launch-once.sh').read_text().replace('/usr/bin/open', f'"{opener}"'))
            env = {**os.environ, 'TMP_CASE': tmp, 'CALLS': str(calls), 'RUNNING': str(running).lower(),
                   'SWITCH': str(switch), 'LAUNCH': str(launch), 'ENDPOINT': str(endpoint), 'VERIFY': str(verify)}
            result = subprocess.run(['bash', str(adapter), str(scripts.parent), 'test-theme'], env=env, capture_output=True)
            return result.returncode, calls.read_text().splitlines()

    def test_success_selects_before_exactly_one_launch_and_verifies(self):
        code, calls = self.run_case()
        self.assertEqual(code, 0)
        self.assertEqual(calls, ['switch', 'launch', 'endpoint', 'injector', 'state', 'verify', 'active'])

    def test_existing_client_is_untouched(self):
        self.assertEqual(self.run_case(running=True), (21, []))

    def test_invalid_theme_does_not_launch(self):
        self.assertEqual(self.run_case(switch=7), (7, ['switch']))

    def test_launch_failure_has_no_retry(self):
        self.assertEqual(self.run_case(launch=8), (8, ['switch', 'launch']))

    def test_endpoint_failure_does_not_launch_again(self):
        self.assertEqual(self.run_case(endpoint=9), (9, ['switch', 'launch', 'endpoint']))

    def test_failed_verification_only_stops_injector(self):
        code, calls = self.run_case(verify=1)
        self.assertEqual(code, 22)
        self.assertEqual(calls.count('launch'), 1)
        self.assertEqual(calls[-2:], ['stop_injector', 'stale'])
        self.assertNotIn('active', calls)

if __name__ == '__main__':
    unittest.main()
