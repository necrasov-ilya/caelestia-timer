pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n
import "TimerLogic.js" as Logic

Singleton {
    id: root

    property var state: Logic.initialState()
    property bool ready: false
    property real nowMs: Date.now()
    property string storageError: ""
    property var keyboardOwners: []
    readonly property string statePath: Quickshell.env("CAELESTIA_TIMER_STATE_FILE") ||
        (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/caelestia-timer/state.json"
    readonly property bool russian: (Tr.language || Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG")).startsWith("ru")
    readonly property string phase: state.phase
    readonly property bool running: phase === "running"
    readonly property bool editable: ready && (phase === "idle" || phase === "finished")
    readonly property real remainingMs: Logic.remaining(state, nowMs)
    readonly property real progress: Math.max(0, Math.min(1, 1 - remainingMs / (state.durationSeconds * 1000)))
    readonly property string timeText: Logic.formatTime(remainingMs)

    function requestKeyboard(owner: var, enabled: bool): void {
        if (!owner)
            return;
        const owners = keyboardOwners.filter(item => item !== owner);
        if (enabled)
            owners.push(owner);
        keyboardOwners = owners;
    }

    function keyboardFor(owner: var): bool {
        return keyboardOwners.indexOf(owner) !== -1;
    }

    function tr(english: string, russianText: string): string {
        return russian ? russianText : english;
    }

    function presetLabel(label: string): string {
        const defaults = { "Quick focus": "Разминка", "Focus": "Фокус", "Deep work": "Глубокая работа", "Long session": "Большой блок" };
        return russian && defaults[label] ? defaults[label] : label;
    }

    function updatePreset(index: int, label: string, seconds: int): void {
        commit(Logic.updatePreset(state, index, label, seconds));
    }

    function commit(next: var): void {
        if (!ready || next === state)
            return;
        const finished = state.phase === "running" && next.phase === "finished";
        state = next;
        storage.setText(JSON.stringify(state));
        if (finished)
            announce();
    }

    function tick(): void {
        nowMs = Date.now();
        commit(Logic.advance(state, nowMs));
    }

    function start(): void {
        nowMs = Date.now();
        commit(Logic.start(state, nowMs));
    }

    function pause(): void {
        nowMs = Date.now();
        commit(Logic.pause(state, nowMs));
    }

    function reset(): void {
        commit(Logic.reset(state));
    }

    function durationText(): string {
        return Logic.formatTime(state.durationSeconds * 1000);
    }

    function validDurationText(text: string): bool {
        return Logic.parseDuration(text) !== null;
    }

    function setDurationText(text: string): bool {
        const seconds = Logic.parseDuration(text);
        if (seconds === null)
            return false;
        setDuration(seconds);
        return true;
    }

    function setDuration(seconds: int): void {
        commit(Logic.setDuration(state, seconds));
    }

    function setSound(enabled: bool): void {
        commit(Object.assign({}, state, { soundEnabled: enabled }));
    }

    function setNotifications(enabled: bool): void {
        commit(Object.assign({}, state, { notificationsEnabled: enabled }));
    }

    function announce(): void {
        if (state.notificationsEnabled)
            Quickshell.execDetached(["notify-send", "-a", "Caelestia Timer", "-i", "chronometer", "-u", "normal",
                tr("Time's up", "Время вышло"), tr("Your timer has finished.", "Таймер завершён.")]);
        if (state.soundEnabled)
            Quickshell.execDetached(["pw-play", decodeURIComponent(Qt.resolvedUrl("assets/finished.wav").toString().replace(/^file:\/\//, ""))]);
    }

    function load(): void {
        if (ready)
            return;
        try {
            state = Logic.restore(JSON.parse(storage.text()));
        } catch (error) {
            console.warn("Caelestia Timer: invalid saved state; starting with defaults", error);
        }
        ready = true;
        tick();
    }

    Timer {
        interval: 250
        repeat: true
        running: root.ready && root.running
        onTriggered: root.tick()
    }

    FileView {
        id: storage
        path: root.statePath
        atomicWrites: true
        printErrors: false
        onLoaded: root.load()
        onLoadFailed: error => {
            if (root.ready)
                return;
            if (error !== FileViewError.FileNotFound)
                root.storageError = root.tr("Cannot read saved timer", "Не удалось прочитать таймер");
            root.ready = true;
            root.tick();
        }
        onSaved: root.storageError = ""
        onSaveFailed: error => {
            root.storageError = root.tr("Cannot save timer", "Не удалось сохранить таймер");
            console.warn("Caelestia Timer: state write failed", error);
        }
    }

    IpcHandler {
        target: "timer"
        function status(): string {
            return JSON.stringify({ ready: root.ready, phase: root.phase, remainingMs: root.remainingMs,
                durationSeconds: root.state.durationSeconds, soundEnabled: root.state.soundEnabled,
                notificationsEnabled: root.state.notificationsEnabled, presets: root.state.presets, storageError: root.storageError });
        }
        function start(): void { root.start(); }
        function pause(): void { root.pause(); }
        function reset(): void { root.reset(); }
        function duration(seconds: int): void { root.setDuration(seconds); }
        function preset(index: int, label: string, seconds: int): void { root.updatePreset(index, label, seconds); }
        function sound(enabled: bool): void { root.setSound(enabled); }
        function notifications(enabled: bool): void { root.setNotifications(enabled); }
    }
}
