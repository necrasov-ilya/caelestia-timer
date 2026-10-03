// Absolute deadlines keep the countdown accurate through sleep and shell restarts.
function validDuration(seconds) {
    return typeof seconds === "number" && Number.isInteger(seconds) && seconds >= 1 && seconds <= 86400;
}

function initialState(seconds) {
    var duration = validDuration(seconds) ? seconds : 1500;
    return { version: 1, durationSeconds: duration, phase: "idle", deadlineMs: 0,
        remainingMs: duration * 1000, soundEnabled: true, notificationsEnabled: true,
        presets: [
            { label: "Quick focus", seconds: 900 },
            { label: "Focus", seconds: 1800 },
            { label: "Deep work", seconds: 3600 },
            { label: "Long session", seconds: 7200 }
        ] };
}

function restore(data) {
    if (!data || data.version !== 1 || !validDuration(data.durationSeconds))
        return initialState();
    var state = initialState(data.durationSeconds);
    state.soundEnabled = data.soundEnabled !== false;
    state.notificationsEnabled = data.notificationsEnabled !== false;
    if (Array.isArray(data.presets) && data.presets.length === 4) {
        state.presets = data.presets.map(function(preset, index) {
            if (!preset || !validDuration(preset.seconds) || typeof preset.label !== "string"
                    || !preset.label.trim() || preset.label.length > 32)
                return state.presets[index];
            return { label: preset.label.trim(), seconds: preset.seconds };
        });
    }
    if (["idle", "running", "paused", "finished"].indexOf(data.phase) < 0)
        return state;
    if (data.phase === "running" && typeof data.deadlineMs === "number"
            && Number.isFinite(data.deadlineMs) && data.deadlineMs > 0) {
        state.phase = "running";
        state.deadlineMs = data.deadlineMs;
    } else if (data.phase === "paused" && typeof data.remainingMs === "number"
            && Number.isFinite(data.remainingMs) && data.remainingMs > 0) {
        state.phase = "paused";
        state.remainingMs = Math.min(data.remainingMs, state.durationSeconds * 1000);
    } else if (data.phase === "finished") {
        state.phase = "finished";
        state.remainingMs = 0;
    }
    return state;
}

function remaining(state, now) {
    if (state.phase === "running")
        return Math.max(0, Math.min(state.durationSeconds * 1000, state.deadlineMs - now));
    return state.phase === "finished" ? 0 : state.remainingMs;
}

function start(state, now) {
    if (state.phase === "running")
        return state;
    var next = Object.assign({}, state);
    next.remainingMs = state.phase === "paused" ? state.remainingMs : state.durationSeconds * 1000;
    next.deadlineMs = now + next.remainingMs;
    next.phase = "running";
    return next;
}

function advance(state, now) {
    if (state.phase !== "running" || remaining(state, now) > 0)
        return state;
    return Object.assign({}, state, { phase: "finished", deadlineMs: 0, remainingMs: 0 });
}

function pause(state, now) {
    if (state.phase !== "running")
        return state;
    if (remaining(state, now) === 0)
        return advance(state, now);
    return Object.assign({}, state, { phase: "paused", deadlineMs: 0, remainingMs: remaining(state, now) });
}

function reset(state) {
    return Object.assign({}, state, { phase: "idle", deadlineMs: 0, remainingMs: state.durationSeconds * 1000 });
}

function setDuration(state, seconds) {
    if (!validDuration(seconds) || state.phase === "running" || state.phase === "paused")
        return state;
    return Object.assign({}, reset(state), { durationSeconds: seconds, remainingMs: seconds * 1000 });
}

function formatTime(milliseconds) {
    var seconds = Math.max(0, Math.ceil(milliseconds / 1000));
    var hours = Math.floor(seconds / 3600);
    var minutes = Math.floor(seconds / 60) % 60;
    var tail = String(seconds % 60).padStart(2, "0");
    return hours > 0 ? hours + ":" + String(minutes).padStart(2, "0") + ":" + tail
                     : String(minutes).padStart(2, "0") + ":" + tail;
}

function updatePreset(state, index, label, seconds) {
    if (!Number.isInteger(index) || index < 0 || index >= 4 || typeof label !== "string"
            || !label.trim() || label.trim().length > 32 || !validDuration(seconds))
        return state;
    var presets = state.presets.slice();
    presets[index] = { label: label.trim(), seconds: seconds };
    return Object.assign({}, state, { presets: presets });
}

// Bare numbers are minutes; clock input supports mm:ss and hh:mm:ss.
function parseDuration(text) {
    if (typeof text !== "string")
        return null;
    var input = text.trim();
    if (!/^[0-9]{1,4}(:[0-9]{1,2}){0,2}$/.test(input))
        return null;
    var parts = input.split(":").map(Number);
    var seconds;
    if (parts.length === 1)
        seconds = parts[0] * 60;
    else if (parts.length === 2 && parts[1] < 60)
        seconds = parts[0] * 60 + parts[1];
    else if (parts.length === 3 && parts[1] < 60 && parts[2] < 60)
        seconds = parts[0] * 3600 + parts[1] * 60 + parts[2];
    return validDuration(seconds) ? seconds : null;
}
