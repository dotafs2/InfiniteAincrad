// Exercise the shipped recorder against an isolated DOM/animation-clock fixture.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { summarize } = require('../tools/device_qa.js');
const source = fs.readFileSync(require.resolve('../tools/device_qa.js'), 'utf8');
let checks = 0;
const check = (ok, label) => { checks++; assert.ok(ok, label); };
check(summarize([]).frames === 0, 'Empty recordings cannot masquerade as performance');
const stats = summarize([10, 16, 16, 32, 60]);
check(stats.frames === 5 && stats.seconds === .134 && stats.p95_ms === 60 && stats.over_25_ms === 2 && stats.over_50_ms === 1, 'Percentiles retain real stalls');
const regular = { window: {}, URLSearchParams, location: { search: '' } };
vm.runInNewContext(source, regular);
check(!regular.window.SinkDeviceQA, 'Normal URL installs no recorder, DOM, clock or hook');
let callback, now = 0, payload, mounted = 0, downloads = 0;
const events = {}, canvasEvents = {}, buttons = [{}, {}], input = { value: 'iPhone test fixture' };
const summary = {}, metrics = {}, host = { style: {}, querySelectorAll: () => buttons,
  querySelector: name => ({ input, summary, div: metrics })[name], addEventListener() {} };
const document = { readyState: 'complete', hidden: false, body: { appendChild() { mounted++; } },
  addEventListener(name, f) { events[name] = f; },
  querySelector: () => ({ addEventListener(name, f) { canvasEvents[name] = f; } }),
  createElement(name) { return name === 'details' ? host : { click() { downloads++; } }; } };
const context = { window: {}, URLSearchParams, location: { search: '?qa=1' }, document,
  navigator: { userAgent: 'Synthetic test, not a real device' }, performance: { now: () => now },
  devicePixelRatio: 3, screen: { width: 390, height: 844 }, innerWidth: 390, innerHeight: 844,
  requestAnimationFrame(f) { callback = f; }, setTimeout(f) { f(); },
  URL: { createObjectURL: () => 'blob:fixture', revokeObjectURL() {} },
  Blob: class { constructor(parts) { payload = JSON.parse(parts.join('')); } } };
vm.runInNewContext(source, context);
const state = value => context.window.SinkDeviceQA.state(value);
const tick = time => { now = time; callback(now); };
const snapshot = () => { buttons[0].onclick(); buttons[1].onclick(); return payload; };
check(mounted === 1 && context.window.SinkDeviceQA.enabled, 'Explicit QA URL installs one local recorder');
buttons[0].onclick();
state({ map: 'city', phase: 'title', paused: false }); tick(1); tick(101);
state({ map: 'city', phase: 'playing', paused: false }); tick(200); tick(216); tick(233);
state({ map: 'city', phase: 'playing', paused: true }); tick(1000); tick(2000);
state({ map: 'city', phase: 'playing', paused: false }); tick(3000); tick(3018);
document.hidden = true; events.visibilitychange(); tick(9000);
document.hidden = false; events.visibilitychange(); tick(10000); tick(10016);
state({ map: 'food', phase: 'playing', paused: false }); tick(11000); tick(11016); tick(11066);
state({ map: 'food', phase: 'complete', paused: false }); tick(12000); tick(12100);
canvasEvents.webglcontextlost();
const report = snapshot();
check(report.city.frames === 4 && report.city.seconds === .067, 'Title, pause, hidden time and resumption gaps are excluded');
check(report.food.frames === 2 && report.food.p99_ms === 50, 'Map switching isolates samples and retains visible frame stalls');
check(report.context_losses === 1 && report.interruptions.length === 2, 'Visibility interruptions and context losses are retained');
check(report.device === 'iPhone test fixture' && report.build === null && report.scope.includes('user supplied'), 'Unverified model/build cannot be silently fabricated');
check(downloads === 1 && report.acceptance.startsWith('No automatic phone PASS'), 'Evidence is downloaded locally and never announces an unmeasured device pass');
check(report.trace.length === 6, 'Phase and gameplay telemetry remain associated with the run');
buttons[0].onclick(); state({ map: 'city', phase: 'playing', paused: false });
for (let i = 0; i <= 72002; i++) tick(20000 + i * 16);
check(!buttons[1].disabled, 'Long recorder auto-stops at its finite frame budget');
buttons[1].onclick();
check(payload.city.frames === 72000 && payload.food.frames === 0, 'Restart resets old data and memory stays bounded');
console.log('DEVICE_QA_TEST ' + JSON.stringify({ checks, failures: [], scope: 'Synthetic DOM/frame clock; not browser rendering or phone evidence' }));
