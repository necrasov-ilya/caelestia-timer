# Caelestia Timer

A timer tab for [Caelestia Shell](https://github.com/caelestia-dots/shell), using its native colours, typography, controls and Material shapes.

The countdown sits on the left, controls in the middle, and four named presets on the right. The wavy progress ring fills as time passes, with a slowly rotating Material shape and gently drifting shapes in the background. Wave motion uses the same native component as the Media tab and pauses when the timer is paused or the tab is hidden. Shell animation settings are respected.

- Start, pause, resume and reset; durations from one second to 24 hours.
- Presets for 15, 30, 60 and 120 minutes; edit their names and durations with the settings button.
- State and presets survive shell restarts. A running timer catches up after sleep; a paused timer stays paused.
- Optional notification and a soft completion sound, with separate switches.
- English and Russian labels follow the shell language; custom preset names stay as entered.

## Installation

Requires an existing Caelestia installation, Python 3 and Bash. Tested with **Caelestia 2.5.0** and **Quickshell 0.3.1** on Hyprland. `notify-send` provides notifications; `pw-play` provides sound. Both are optional.

```sh
git clone https://github.com/necrasov-ilya/caelestia-timer.git
cd caelestia-timer
./install.sh --check
./install.sh --restart
```

Open Dashboard and select **Timer**, next to Media. Enter a duration as `mm:ss`, `hh:mm:ss`, or a number of minutes (for example, `15`). For a manual restart, omit `--restart` and restart Caelestia yourself.

The installer checks the dashboard structure before writing anything. It adds a user-level module and small marked integration blocks in `shell.qml`, `modules/dashboard/Content.qml` and `modules/drawers/ContentWindow.qml`. Keyboard focus is enabled on demand while the timer tab is open, so duration and preset fields can receive input.

For a packaged shell, the installer keeps other files linked to the system installation and replaces the three integration files locally. Original files and links are backed up. Existing personal settings are preserved; system package files are never written.

For a custom checkout or installation location:

```sh
./install.sh --target /path/to/user-owned/caelestia
# Or explicitly select the packaged shell to mirror:
./install.sh --base /path/to/packaged/caelestia
```

`--restart` supports the default `caelestia` configuration only. This is a dashboard addon with an installer, rather than an official Caelestia plugin. Other shell versions may require an adjusted integration; unsupported layouts are rejected without changes.

## Update and removal

```sh
git pull
./install.sh --restart
# Remove the addon:
./uninstall.sh --restart
```

Updates replace addon files while retaining timer state, presets and unrelated shell edits. Local edits inside the installed addon are detected and must be backed up before updating or removing it.

Removal restores original integration files or removes only the marked blocks when you have made other edits. Saved state remains in `${XDG_STATE_HOME:-$HOME/.local/state}/caelestia-timer/state.json`.

The three patched integration files are local copies. Before updating Caelestia itself, remove the addon, update the shell, then reinstall it; this lets the installer check the new layout and apply the integration to the current files. If those files contain personal edits, merge the upstream changes as you normally would.

## IPC

Control the timer from a key binding or another tool:

```sh
qs -c caelestia ipc call timer status
qs -c caelestia ipc call timer duration 1800
qs -c caelestia ipc call timer start
qs -c caelestia ipc call timer pause
qs -c caelestia ipc call timer reset
qs -c caelestia ipc call timer preset 0 "Tea break" 900
qs -c caelestia ipc call timer sound false
qs -c caelestia ipc call timer notifications true
```

Durations are in seconds; preset indexes run from 0 to 3. Duration changes are accepted when idle or finished. `start` also resumes a paused timer. A completion is announced once, including if its deadline passed while the shell was stopped.

## Development

```sh
node --test tests/timer.test.cjs
python3 -m unittest discover -s tests -p 'test_*.py'
# Requires a running graphical session and installed Caelestia:
python3 tests/runtime_smoke.py --shell "$HOME/.config/quickshell/caelestia"
```

The runtime check uses separate state and silent substitutes for the notification and sound commands. It does not change the running shell's timer. `CAELESTIA_TIMER_STATE_FILE` can override the state file for an isolated preview.

Licensed under GPL-3.0-only; see [LICENSE](LICENSE). The visual language and animated Material background are inspired by Caelestia Shell and its Media tab. Native controls come from the installed shell; Material shapes are provided by M3Shapes. The bundled completion sound is generated for this project.
