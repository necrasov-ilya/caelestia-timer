import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('setup', Path(__file__).parents[1] / 'scripts/setup.py')
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)

SHELL = 'import QtQuick\nShellRoot {\n    GSFLoader {}\n}\n'
CONTENT = '''import QtQuick
Item {
    property var tabs: [
            {
                component: weatherComponent,
                text: "Weather"
            }
    ]
            Component {
                id: weatherComponent
                Item {}
            }
}
'''
WINDOW = 'import QtQuick\nStyledWindow {\n' + setup.KEYBOARD_LINE + '\n    mask: hasFullscreen ? emptyRegion : regions\n}\n'


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.base = self.root / 'package'
        self.target = self.root / 'user'
        for name, text in zip(setup.FILES, (SHELL, CONTENT, WINDOW)):
            path = self.base / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        (self.base / 'services').mkdir()
        (self.base / 'services/Example.qml').write_text('original service')
        self.env = patch.dict(os.environ, {'XDG_STATE_HOME': str(self.root / 'state')})
        self.env.start()
        self.addCleanup(self.env.stop)

    def install(self):
        setup.install(self.target, self.base)

    def test_check_writes_nothing_and_incompatible_layout_is_rejected(self):
        setup.install(self.target, self.base, check=True)
        self.assertFalse(self.target.exists())
        (self.base / setup.FILES[1]).write_text('Item {}')
        with self.assertRaises(ValueError):
            self.install()
        self.assertFalse(self.target.exists())

    def test_overlay_install_update_remove_never_modify_package(self):
        before = {str(p): p.read_bytes() for p in self.base.rglob('*') if p.is_file()}
        self.install()
        for name in setup.FILES:
            self.assertFalse((self.target / name).is_symlink())
        self.assertTrue((self.target / 'services/Example.qml').is_symlink())
        self.assertTrue((self.target / setup.MODULE / 'TimerTab.qml').exists())
        self.install()
        setup.uninstall(self.target)
        self.assertFalse((self.target / setup.MODULE).exists())
        self.assertFalse((self.target / setup.RECORD).exists())
        self.assertEqual(before, {str(p): p.read_bytes() for p in self.base.rglob('*') if p.is_file()})

    def test_existing_regular_files_and_symlinked_directories_restore(self):
        self.target.mkdir()
        (self.target / 'shell.qml').write_text(SHELL + '// user settings\n')
        (self.target / 'modules').symlink_to(self.base / 'modules', target_is_directory=True)
        self.install()
        self.assertFalse((self.target / 'modules').is_symlink())
        setup.uninstall(self.target)
        self.assertTrue((self.target / 'modules').is_symlink())
        self.assertEqual((self.target / 'shell.qml').read_text(), SHELL + '// user settings\n')

    def test_user_changes_survive_update_and_removal(self):
        self.install()
        for name in setup.FILES:
            with (self.target / name).open('a') as output:
                output.write('// custom after install\n')
        service = self.target / 'services/Example.qml'
        service.unlink()
        service.write_text('custom service')
        self.install()
        setup.uninstall(self.target)
        for name, original in zip(setup.FILES, (SHELL, CONTENT, WINDOW)):
            self.assertEqual((self.target / name).read_text(), original + '// custom after install\n')
        self.assertEqual(service.read_text(), 'custom service')

    def test_modified_links_and_owned_module_are_preserved(self):
        self.install()
        service = self.target / 'services/Example.qml'
        service.unlink()
        replacement = self.root / 'replacement.qml'
        replacement.write_text('replacement')
        service.symlink_to(replacement)
        module = self.target / setup.MODULE / 'TimerLogic.js'
        original = module.read_bytes()
        module.write_text('// custom timer')
        with self.assertRaises(ValueError):
            self.install()
        with self.assertRaises(ValueError):
            setup.uninstall(self.target)
        self.assertEqual(module.read_text(), '// custom timer')
        module.write_bytes(original)
        setup.uninstall(self.target)
        self.assertEqual(service.resolve(), replacement)

    def test_partial_install_rolls_back_originals(self):
        self.target.mkdir()
        for name in setup.FILES:
            path = self.target / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.symlink_to(self.base / name)
        with patch.object(setup.shutil, 'copytree', side_effect=OSError('simulated copy failure')):
            with self.assertRaises(OSError):
                self.install()
        for name in setup.FILES:
            self.assertTrue((self.target / name).is_symlink())
            self.assertEqual((self.target / name).resolve(), self.base / name)
        self.assertFalse((self.target / setup.RECORD).exists())
        self.assertFalse((self.target / setup.MODULE).exists())


if __name__ == '__main__':
    unittest.main()
