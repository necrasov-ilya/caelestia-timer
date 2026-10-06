# Caelestia Timer

A timer right in the [Caelestia Shell](https://github.com/caelestia-dots/shell) dashboard. Native styling, animated countdown — no separate app.

<p align="center">
  <a href="LICENSE"><img alt="License GPL-3.0-only" src="https://img.shields.io/badge/license-GPL--3.0--only-blue"></a>&nbsp;
  <img alt="Tested with Caelestia 2.5.0" src="https://img.shields.io/badge/Caelestia-2.5.0-6046ff">&nbsp;
  <img alt="Tested with Quickshell 0.3.1" src="https://img.shields.io/badge/Quickshell-0.3.1-ac2954">
</p>

<p align="center">
  English · <a href="docs/README.ru.md">Русский</a>
</p>

## Enough theory — here's what you get

- A countdown from one second to 24 hours, with pause, resume and reset.
- Four presets for 15, 30, 60 and 120 minutes. Change their names and durations.
- Timer and presets saved across restarts. Elapsed time accounted for after sleep.
- A notification and a soft completion sound — switch either off.
- English and Russian labels, native Caelestia animations.

![Preset selection and timer controls](docs/demo/controls.gif)

<details>
<summary>When the countdown ends</summary>

![Countdown reaching zero](docs/demo/completion.gif)

</details>

## Installation

Requires Caelestia, Python 3 and Bash. Tested with **Caelestia 2.5.0 / Quickshell 0.3.1** on Hyprland.

```sh
git clone https://github.com/necrasov-ilya/caelestia-timer.git
cd caelestia-timer
./install.sh --check
./install.sh --restart
```

Open **Dashboard → Timer**, next to Media. Pick a preset or enter minutes (`15`), `mm:ss` or `hh:mm:ss`.

## Update and removal

```sh
git pull
./install.sh --restart
# Remove
./uninstall.sh --restart
```

State and presets are retained. **Before updating Caelestia itself, remove the addon, update the shell, then reinstall it.** The integration files are local copies.

<details>
<summary>Technical details, IPC and development</summary>

### Installer

This is not an official plugin. The installer checks the shell layout before making changes, creates backups and leaves system files and personal settings untouched. Unsupported layouts are rejected without changes.

For a packaged shell, it creates a user-level copy. `shell.qml`, `modules/dashboard/Content.qml` and `modules/drawers/ContentWindow.qml` become local files. The rest stay linked. Removal restores originals or removes only marked blocks if you have made other edits. Merge personal integration-file edits with Caelestia updates manually. Back up edits inside the addon itself before updating or removing it.

```sh
./install.sh --target /path/to/user-owned/caelestia
./install.sh --base /path/to/packaged/caelestia
```

`--restart` supports only the default `caelestia` configuration. Omit it to restart manually. Notifications need `notify-send`, sound needs `pw-play` (both optional). State lives in `${XDG_STATE_HOME:-$HOME/.local/state}/caelestia-timer/state.json` and remains after removal.

### IPC

For key bindings and scripts

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

Durations are in seconds, preset indexes from 0 to 3. Change duration when idle or finished. `start` also resumes a paused timer. Completion is announced once, even if the timer expired while the shell was stopped.

### Development

```sh
node --test tests/timer.test.cjs
python3 -m unittest discover -s tests -p 'test_*.py'
# Requires a graphical session and installed Caelestia
python3 tests/runtime_smoke.py --shell "$HOME/.config/quickshell/caelestia"
```

The runtime check uses isolated state and silent notification/sound substitutes, leaving the current timer untouched. Set `CAELESTIA_TIMER_STATE_FILE` for an isolated preview.

</details>

GPL-3.0-only · [License](LICENSE). Styling by Caelestia Shell, Material shapes by M3Shapes. Sound created for this project.
