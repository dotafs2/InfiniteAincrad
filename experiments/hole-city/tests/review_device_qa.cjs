// Independent negative-URL, pre-DOM boot and bounded-event recorder review.
const assert = require('node:assert/strict'), fs = require('node:fs'), vm = require('node:vm');
const source = fs.readFileSync(require.resolve('../tools/device_qa.js'), 'utf8');
const bootstrapPath = '/tmp/hole-device-review-bootstrap.json';
const bootstrap = JSON.parse(fs.readFileSync(bootstrapPath, 'utf8'));
let checks = 0;
const check = (ok, label) => { checks++; assert.ok(ok, label); };
for (const query of ['', '?qa=0', '?qa=true', '?qa=01', '?qa=2', '?other=1']) {
  const context = { window: {}, URLSearchParams, location: { search: query },
    requestAnimationFrame() { throw Error('Normal page scheduled a recorder frame'); },
    document: new Proxy({}, { get() { throw Error('Normal page touched DOM'); } }) };
  vm.runInNewContext(source, context);
  check(!context.window.SinkDeviceQA, 'Non-opt-in URL remains untouched: ' + query);
}
for (const [api, expected] of [[undefined, ['original']], [{ enabled: false }, ['original']], [{ enabled: true }, ['--', '--test', '--device-qa']]]) {
  let args;
  vm.runInNewContext(bootstrap.hook, { window: { SinkDeviceQA: api }, GODOT_CONFIG: { args: ['original'] }, Engine: function(c) { args = c.args; } });
  check(JSON.stringify(args) === JSON.stringify(expected), 'Actual injection hook isolates only an enabled recorder');
}
let mounted = 0, raf, now = 0, report, downloadCount = 0;
const events = {}, canvasEvents = {}, buttons = [{}, {}], widgets = { summary: {}, div: {}, input: { value: '' } };
const host = { style: {}, querySelectorAll() { return buttons; }, querySelector(k) { return widgets[k]; }, addEventListener() {} };
const document = {
  readyState: 'loading', hidden: false,
  body: { appendChild() { mounted++; } },
  addEventListener(name, f) { events[name] = f; },
  querySelector() { return { addEventListener(name, f) { canvasEvents[name] = f; } }; },
  createElement(name) { return name === 'details' ? host : { click() { downloadCount++; } }; }
};
const window = { SINK_QA_BUILD: bootstrap.metadata };
const context = { window, URLSearchParams, location: { search: '?qa=1' }, document,
  performance: { now() { return now; } }, navigator: { userAgent: 'Independent VM fixture, no real device' },
  devicePixelRatio: 1, screen: { width: 540, height: 960 }, innerWidth: 540, innerHeight: 960,
  requestAnimationFrame(f) { raf = f; }, setTimeout(f) { f(); },
  URL: { createObjectURL() { return 'blob:independent-fixture'; }, revokeObjectURL() {} },
  Blob: class { constructor(parts) { report = JSON.parse(parts.join('')); } }
};
vm.runInNewContext(source, context);
check(window.SinkDeviceQA.enabled && mounted === 0 && !raf, 'QA isolation is available before DOM while UI/clock await mount');
events.DOMContentLoaded();
check(mounted === 1 && typeof raf === 'function', 'DOMContentLoaded creates exactly one recorder owner');
buttons[0].onclick();
for (let i = 0; i < 6001; i++) window.SinkDeviceQA.state({ map: 'city', phase: 'playing', paused: false, score: i, radius: 1 + i / 1000 });
for (let i = 0; i < 5007; i++) { document.hidden = Boolean(i % 2); events.visibilitychange(); }
const tick = time => { now = time; raf(now); };
tick(1); tick(17);
window.SinkDeviceQA.state({ map: 'city', phase: 'playing', paused: true }); tick(1000);
window.SinkDeviceQA.state({ map: 'city', phase: 'playing', paused: false }); tick(2000); tick(2016);
window.SinkDeviceQA.state({ map: 'food', phase: 'playing', paused: false }); tick(3000); tick(3033);
document.hidden = true; events.visibilitychange(); tick(4000);
document.hidden = false; events.visibilitychange(); tick(5000); tick(5050);
for (let i = 0; i < 5; i++) canvasEvents.webglcontextlost();
buttons[0].onclick(); buttons[1].onclick();
check(report.interruptions.length === 3000 && report.omitted_visibility_events === 2009, 'Visibility event memory is bounded and omitted evidence is explicit');
check(report.trace.length === 3000 && report.omitted_trace_events === 3004, 'Telemetry memory is bounded without pretending the trace is complete');
check(report.city.frames === 2 && report.city.seconds === .032, 'Pause and context transition gaps do not pollute city samples');
check(report.food.frames === 2 && report.food.seconds === .083, 'Food samples exclude hidden gaps and preserve visible 50ms stall');
check(report.device === 'Unspecified' && report.user_agent.includes('VM fixture'), 'No hardware model is invented');
check(JSON.stringify(report.build) === JSON.stringify(bootstrap.metadata), 'Download retains the exact inserted package/wasm/recorder hashes');
check(report.context_losses === 5 && downloadCount === 1, 'Context failures are recorded and evidence is downloaded once locally');
check(report.acceptance.includes('No automatic phone PASS') && report.scope.includes('not a direct GPU timer'), 'Cadence evidence cannot claim GPU or phone certification');
fs.unlinkSync(bootstrapPath);
console.log('DEVICE_RECORDER_REVIEW ' + JSON.stringify({ checks, failures: [], scope: 'Independent synthetic VM/clock/DOM; not browser or phone performance' }));
