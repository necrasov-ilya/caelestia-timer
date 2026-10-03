const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const logic = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../qml/TimerLogic.js'), 'utf8'), logic);

test('absolute deadline catches up after suspend and completes only once', () => {
    const running = logic.start(logic.initialState(60), 1000);
    assert.equal(logic.remaining(running, 11000), 50000);
    const finished = logic.advance(running, 121000);
    assert.equal(finished.phase, 'finished');
    assert.equal(logic.advance(finished, 200000), finished);
    assert.equal(logic.start(running, 2000), running);
});

test('pause retains subsecond remainder through a full restart', () => {
    const paused = logic.pause(logic.start(logic.initialState(60), 1000), 11250);
    const restored = logic.restore(JSON.parse(JSON.stringify(paused)));
    assert.equal(logic.remaining(restored, 999999), 49750);
    const resumed = logic.start(restored, 200000);
    assert.equal(resumed.deadlineMs, 249750);
    assert.equal(logic.advance(resumed, 249749), resumed);
    assert.equal(logic.advance(resumed, 249750).phase, 'finished');
});

test('restart restores running and expired deadlines without replaying finished alarms', () => {
    const running = logic.start(logic.initialState(5), 1000);
    const restored = logic.restore(JSON.parse(JSON.stringify(running)));
    assert.equal(logic.remaining(restored, 4000), 2000);
    const expired = logic.advance(restored, 10000);
    assert.equal(expired.phase, 'finished');
    const finished = logic.restore(JSON.parse(JSON.stringify(expired)));
    assert.equal(logic.advance(finished, 20000), finished);
});

test('pause at deadline completes; reset and duration changes obey current phase', () => {
    const running = logic.start(logic.initialState(1), 1000);
    assert.equal(logic.pause(running, 2000).phase, 'finished');
    assert.equal(logic.setDuration(running, 20), running);
    const paused = logic.pause(running, 1500);
    assert.equal(logic.setDuration(paused, 20), paused);
    const reset = logic.reset(paused);
    assert.equal(reset.phase, 'idle');
    assert.equal(logic.setDuration(reset, 20).remainingMs, 20000);
});

test('invalid persisted values fall back safely; settings survive reset', () => {
    for (const value of [null, {}, {version: 9}, {version: 1, durationSeconds: Infinity},
        {version: 1, durationSeconds: '25'}, {version: 1, durationSeconds: -1}])
        assert.equal(logic.restore(value).phase, 'idle');
    const state = logic.restore({version: 1, durationSeconds: 60, phase: 'paused', remainingMs: 999999,
        soundEnabled: false, notificationsEnabled: false});
    assert.equal(state.remainingMs, 60000);
    assert.equal(logic.reset(state).soundEnabled, false);
    assert.equal(logic.reset(state).notificationsEnabled, false);
    assert.equal(logic.restore({version: 1, durationSeconds: 10, phase: 'running', deadlineMs: 'bad'}).phase, 'idle');
});

test('format does not show zero before completion and supports hours', () => {
    assert.equal(logic.formatTime(1), '00:01');
    assert.equal(logic.formatTime(0), '00:00');
    assert.equal(logic.formatTime(3600000), '1:00:00');
    assert.equal(logic.formatTime(86400000), '24:00:00');
});
