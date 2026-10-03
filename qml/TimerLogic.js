// Absolute deadlines keep the countdown accurate through sleep and shell restarts.
function validDuration(seconds) {
    return typeof seconds === "number" && Number.isInteger(seconds) && seconds >= 1 && seconds <= 86400;
}

function initialState(seconds) {
    var duration = validDuration(seconds) ? seconds : 1500;
    return { version: 1, durationSeconds: duration, phase: "idle", deadlineMs: 0,
        remainingMs: duration * 1000, soundEnabled: true, notificationsEnabled: true };
}

function restore(data) {
    if (!data || data.version !== 1 || !validDuration(data.durationSeconds))
        return initialState();
    var state = initialState(data.durationSeconds);
    state.soundEnabled = data.soundEnabled !== false;
    state.notificationsEnabled = data.notificationsEnabled !== false;
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
