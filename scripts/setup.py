#!/usr/bin/env python3
"""Install a user-level dashboard addon, preserving unrelated shell changes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parents[1]
MODULE = Path('modules/dashboard/caelestiaTimer')
RECORD = '.caelestia-timer-install.json'
BACKUP = '.caelestia-timer-backup'
FILES = ('shell.qml', 'modules/dashboard/Content.qml', 'modules/drawers/ContentWindow.qml')
BLOCK_COUNTS = dict(zip(FILES, (2, 3, 2)))
KEYBOARD_LINE = '    WlrLayershell.keyboardFocus: screenState.launcher || screenState.session ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None\n'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def atomic_write(path, data):
    """Replace the directory entry, never write through a packaged-file symlink."""
    fd, temporary = tempfile.mkstemp(prefix='.timer-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as output:
            output.write(data)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def block(name, content):
    return f'// BEGIN caelestia-timer {name}\n{content}// END caelestia-timer {name}\n'


def insert_once(text, anchor, content):
    if text.count(anchor) != 1:
        raise ValueError('Unsupported shell layout: expected a unique integration point.')
    return text.replace(anchor, content + anchor, 1)


def integrate(name, text):
    if 'BEGIN caelestia-timer' in text:
        raise ValueError('Timer markers already exist without an installation record.')
    if name == 'shell.qml':
        text = insert_once(text, 'ShellRoot {', block('import', 'import "modules/dashboard/caelestiaTimer" as CaelestiaTimer\n'))
        text = insert_once(text, '    GSFLoader {}', block('service', '    CaelestiaTimer.TimerBootstrap {}\n'))
    elif name == 'modules/dashboard/Content.qml':
        text = insert_once(text, '\nItem {', '\n' + block('import', 'import "caelestiaTimer" as CaelestiaTimer\n').rstrip('\n'))
        text = insert_once(text, '            {\n                component: weatherComponent,', block('tab',
            '            {\n                component: caelestiaTimerComponent,\n'
            '                iconName: "timer",\n                text: CaelestiaTimer.TimerService.tr("Timer", "Таймер"),\n'
            '                enabled: true\n            },\n'))
        text = insert_once(text, '            Component {\n                id: weatherComponent', block('component',
            '            Component {\n                id: caelestiaTimerComponent\n'
            '                CaelestiaTimer.TimerTab {\n'
            '                    keyboardOwner: root.screenState\n'
            '                    dashboardOpen: root.screenState.dashboard\n'
            '                    keyboardActive: dashboardOpen && root.dashboardTabs[root.screenState.dashboardTab]?.component === caelestiaTimerComponent\n'
            '                }\n            }\n'))
    else:
        text = insert_once(text, 'StyledWindow {', block('import', 'import "../dashboard/caelestiaTimer" as CaelestiaTimer\n'))
        anchor = KEYBOARD_LINE
        if text.count(anchor) != 1:
            raise ValueError('Unsupported dashboard keyboard focus configuration.')
        text = text.replace(anchor, block('keyboard',
            '    WlrLayershell.keyboardFocus: screenState.launcher || screenState.session || CaelestiaTimer.TimerService.keyboardFor(screenState) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None\n'), 1)
    return text


def strip_blocks(text):
    text = re.sub(r'^// BEGIN caelestia-timer keyboard\n.*?^// END caelestia-timer keyboard\n',
                  lambda match: KEYBOARD_LINE, text, flags=re.MULTILINE | re.DOTALL)
    return re.sub(r'^// BEGIN caelestia-timer ([a-z]+)\n.*?^// END caelestia-timer \1\n', '', text,
                  flags=re.MULTILINE | re.DOTALL)


def mirror(source, target, created):
    """A local directory tree with links to upstream files allows package updates."""
    target.mkdir(parents=True, exist_ok=True)
    for entry in source.iterdir():
        destination = target / entry.name
        if entry.is_dir():
            if destination.is_symlink():
                continue
            mirror(entry, destination, created)
        elif not os.path.lexists(destination):
            destination.symlink_to(entry.resolve())
            created.append({'path': str(destination), 'link': os.readlink(destination)})


def localize_parents(target, path, created, directories):
    """Materialize linked directories before writing any files underneath them."""
    current = target
    for part in path.relative_to(target).parts[:-1]:
        current = current / part
        if current.is_symlink():
            link = os.readlink(current)
            source = current.resolve()
            if not source.is_dir():
                raise ValueError(f'Not a directory: {current}')
            current.unlink()
            current.mkdir()
            directories.append({'path': str(current), 'link': link})
            mirror(source, current, created)
        else:
            current.mkdir(exist_ok=True)


def restore_original(target, name, original):
    path = target / name
    if original['kind'] == 'link':
        path.unlink(missing_ok=True)
        path.symlink_to(original['link'])
    else:
        atomic_write(path, (target / BACKUP / name).read_bytes())


def clean_overlay(created, directories):
    for item in reversed(created):
        path = Path(item['path'])
        if path.is_symlink() and os.readlink(path) == item['link']:
            path.unlink()
        # A link replaced with a user-owned file is intentionally preserved.
    for item in reversed(directories):
        path = Path(item['path'])
        for parent in sorted(path.rglob('*'), key=lambda p: len(p.parts), reverse=True):
            if parent.is_dir() and not parent.is_symlink():
                try:
                    parent.rmdir()
                except OSError:
                    pass
        try:
            path.rmdir()
        except OSError:
            continue
        path.symlink_to(item['link'])


def module_hashes(path):
    return {str(p.relative_to(path)): digest(p.read_bytes()) for p in sorted(path.rglob('*')) if p.is_file()}


def install(target, base, check=False):
    record_path = target / RECORD
    record = json.loads(record_path.read_text()) if record_path.exists() else None
    source = target if (target / 'shell.qml').exists() else base
    if not source or not all((source / name).is_file() for name in FILES):
        raise ValueError('Caelestia not found. Use --base for a packaged shell or --target for a manual installation.')
    if target.is_symlink():
        raise ValueError('The shell root is a symlink. Select its user-owned checkout with --target.')
    if str(target.resolve()).startswith(('/etc/', '/usr/', '/opt/')):
        raise ValueError('Choose a user-owned shell directory; system packages must not be modified.')

    patched = {}
    for name in FILES:
        text = (source / name).read_text()
        if record:
            expected = BLOCK_COUNTS[name]
            if text.count('// BEGIN caelestia-timer ') != expected:
                raise ValueError(f'Integration was modified in {name}; restore the timer blocks before updating.')
            patched[name] = text
        else:
            patched[name] = integrate(name, text)
    module_path = target / MODULE
    if record:
        if module_hashes(module_path) != record['module_hashes']:
            raise ValueError('Installed timer files have local changes. Back them up before updating or removing.')
    elif os.path.lexists(module_path):
        raise ValueError(f'Refusing to overwrite an existing module: {module_path}')
    if check:
        print(f'Compatible dashboard found: {source}\nInstallation target: {target}')
        return

    created = record['created'] if record else []
    directories = record['directories'] if record else []
    originals = record['originals'] if record else {}
    updated = []
    previous_module = None
    staging = None
    try:
        if source != target:
            mirror(source, target, created)
        target.mkdir(parents=True, exist_ok=True)
        for name in FILES:
            path = target / name
            localize_parents(target, path, created, directories)
            if not record:
                originals[name] = {'kind': 'link', 'link': os.readlink(path)} if path.is_symlink() else {'kind': 'file'}
                backup = target / BACKUP / name
                backup.parent.mkdir(parents=True, exist_ok=True)
                backup.write_bytes(path.read_bytes())
                atomic_write(path, patched[name].encode())
                updated.append(name)
        localize_parents(target, module_path, created, directories)
        staging = Path(tempfile.mkdtemp(prefix='.timer-module-', dir=module_path.parent))
        shutil.copytree(REPO / 'qml', staging, dirs_exist_ok=True)
        if module_path.exists():
            previous_module = module_path.with_name('.timer-previous')
            if previous_module.exists():
                raise ValueError('An unfinished update backup exists; resolve it before updating.')
            os.replace(module_path, previous_module)
        os.replace(staging, module_path)
        state_dir = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'caelestia-timer'
        state_dir.mkdir(parents=True, exist_ok=True)
        result = {'version': 1, 'created': created, 'directories': directories, 'originals': originals,
                  'patched_hashes': record['patched_hashes'] if record else {name: digest(patched[name].encode()) for name in FILES},
                  'module_hashes': module_hashes(module_path)}
        atomic_write(record_path, (json.dumps(result, indent=2) + '\n').encode())
    except Exception:
        for name in reversed(updated):
            restore_original(target, name, originals[name])
        if previous_module and previous_module.exists():
            if module_path.exists():
                shutil.rmtree(module_path)
            os.replace(previous_module, module_path)
        elif not record and module_path.exists():
            shutil.rmtree(module_path)
        if staging and staging.exists():
            shutil.rmtree(staging)
        if not record:
            clean_overlay(created, directories)
            shutil.rmtree(target / BACKUP, ignore_errors=True)
        raise
    if previous_module:
        shutil.rmtree(previous_module)
    print(f'Timer installed: {target}\nRestart Caelestia to load the new tab (or pass --restart).')
    for command, purpose in [('notify-send', 'notifications'), ('pw-play', 'sound')]:
        if not shutil.which(command):
            print(f'Optional command missing: {command} ({purpose}).')


def uninstall(target, check=False):
    record_path = target / RECORD
    if not record_path.exists():
        print('Timer is not installed here.')
        return
    record = json.loads(record_path.read_text())
    if module_hashes(target / MODULE) != record['module_hashes']:
        raise ValueError('Installed timer files have local changes; back them up before removing.')
    cleaned = {}
    for name in FILES:
        text = (target / name).read_text()
        expected = BLOCK_COUNTS[name]
        if text.count('// BEGIN caelestia-timer ') != expected:
            raise ValueError(f'Integration markers were changed in {name}; remove the integration manually.')
        cleaned[name] = strip_blocks(text)
        if 'caelestiaTimer' in cleaned[name] or 'CaelestiaTimer' in cleaned[name]:
            raise ValueError(f'Additional timer references remain in {name}; resolve them before removing.')
    if check:
        print(f'Timer can be removed from {target}')
        return
    for name in FILES:
        if digest((target / name).read_bytes()) == record['patched_hashes'][name]:
            restore_original(target, name, record['originals'][name])
        else:
            atomic_write(target / name, cleaned[name].encode())
    shutil.rmtree(target / MODULE)
    clean_overlay(record['created'], record['directories'])
    shutil.rmtree(target / BACKUP)
    record_path.unlink()
    print('Timer removed. Saved presets and timer state are kept in the user state directory.')


def main():
    config = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config')))
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['install', 'uninstall'])
    parser.add_argument('--target', type=Path, default=config / 'quickshell/caelestia')
    parser.add_argument('--base', type=Path, help='Packaged shell to mirror into the user configuration')
    parser.add_argument('--check', action='store_true', help='Check compatibility without writing files')
    parser.add_argument('--restart', action='store_true', help='Restart the running caelestia configuration')
    args = parser.parse_args()
    target = args.target.expanduser().absolute()
    bases = [Path(p) / 'quickshell/caelestia' for p in os.environ.get('XDG_CONFIG_DIRS', '/etc/xdg').split(':')]
    base = args.base or next((p for p in bases if (p / 'shell.qml').exists()), None)
    try:
        if args.restart and target != (config / 'quickshell/caelestia').absolute():
            raise ValueError('--restart is only supported for the default configuration.')
        if args.action == 'install':
            install(target, base, args.check)
        else:
            uninstall(target, args.check)
        if args.restart and not args.check:
            subprocess.run(['qs', '-c', 'caelestia', 'kill'], check=False)
            subprocess.run(['caelestia', 'shell', '-d'] if shutil.which('caelestia') else
                           ['qs', '-c', 'caelestia', '-n', '-d'], check=True)
    except (ValueError, OSError, KeyError) as error:
        print(f'Error: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
