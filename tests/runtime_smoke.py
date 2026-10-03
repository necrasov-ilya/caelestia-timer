#!/usr/bin/env python3
"""Exercise the actual Quickshell service with isolated state and silent alarm stubs."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--shell', type=Path, default=Path.home() / '.config/quickshell/caelestia')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='caelestia-timer-test-') as directory:
        root = Path(directory)
        (root / 'qml').symlink_to(REPO / 'qml')
        for name in ('components', 'services', 'utils', 'modules'):
            (root / name).symlink_to(args.shell / name)
        (root / 'shell.qml').write_text('import QtQuick\nimport Quickshell\nimport "qml" as Addon\nShellRoot { Addon.TimerBootstrap {} }\n')
        binary = root / 'bin'
        binary.mkdir()
        for name in ('notify-send', 'pw-play'):
            path = binary / name
            path.write_text('#!/usr/bin/env python3\nimport os,sys\nwith open(os.environ["TIMER_ALARM_LOG"],"a") as output:\n    output.write(os.path.basename(sys.argv[0])+"\\n")\n')
            path.chmod(0o755)
        env = dict(os.environ, CAELESTIA_TIMER_STATE_FILE=str(root / 'state.json'),
                   TIMER_ALARM_LOG=str(root / 'alarms'), PATH=str(binary) + ':' + os.environ['PATH'])
        process = None
        log = (root / 'runtime.log').open('w')

        def call(method, *values):
            result = subprocess.run(['qs', '-p', str(root), 'ipc', 'call', 'timer', method, *map(str, values)],
                                    capture_output=True, text=True, timeout=5)
            if result.returncode:
                raise RuntimeError(result.stdout + result.stderr)
            return result.stdout.strip()

        def status():
            return json.loads(call('status'))

        def wait_for(predicate, seconds=8):
            deadline = time.monotonic() + seconds
            while time.monotonic() < deadline:
                try:
                    value = status()
                    if predicate(value):
                        return value
                except (RuntimeError, json.JSONDecodeError):
                    pass
                time.sleep(0.05)
            raise AssertionError('Service did not reach the expected state.\n' + (root / 'runtime.log').read_text())

        def start():
            nonlocal process
            process = subprocess.Popen(['qs', '-p', str(root), '--no-color'], env=env,
                                       stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)
            return wait_for(lambda value: value['ready'])

        def stop():
            nonlocal process
            if process:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                process = None

        def alarms(expected):
            deadline = time.monotonic() + 3
            while time.monotonic() < deadline:
                names = (root / 'alarms').read_text().splitlines() if (root / 'alarms').exists() else []
                if len(names) == expected:
                    assert names.count('notify-send') == expected // 2
                    assert names.count('pw-play') == expected // 2
                    return
                time.sleep(0.05)
            raise AssertionError(f'Expected {expected} alarm commands, got {names}')

        try:
            initial = start()
            assert [preset['seconds'] for preset in initial['presets']] == [900, 1800, 3600, 7200]
            call('preset', 0, 'Tea break', 420)
            call('duration', 2)
            call('start')
            time.sleep(0.35)
            call('pause')
            paused = status()
            assert 1000 < paused['remainingMs'] < 2000
            time.sleep(0.15)  # Allow the atomic state write to finish before a process restart.
            stop()
            time.sleep(0.2)
            restored = start()
            assert restored['phase'] == 'paused'
            assert restored['remainingMs'] == paused['remainingMs']
            assert restored['presets'][0] == {'label': 'Tea break', 'seconds': 420}
            call('start')
            wait_for(lambda value: value['phase'] == 'finished')
            alarms(2)
            stop()
            assert start()['phase'] == 'finished'
            time.sleep(0.3)
            alarms(2)
            call('reset')
            call('duration', 2)
            call('start')
            time.sleep(0.15)
            stop()
            time.sleep(2.1)
            assert start()['phase'] == 'finished'
            alarms(4)
            time.sleep(0.3)
            alarms(4)
            assert not status()['storageError']
            output = (root / 'runtime.log').read_text()
            assert 'ERROR:' not in output and '@qml/' not in output, output
            print('Quickshell: pause, resume, preset persistence, expired restart and single alarms passed.')
        finally:
            stop()
            log.close()


if __name__ == '__main__':
    main()
