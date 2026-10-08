/* Opt-in browser frame-cadence recorder. No network upload or player save. */
(() => {
  'use strict';
  function summarize(values) {
    if (!values.length) return { frames: 0, seconds: 0 };
    const sorted = values.slice().sort((a, b) => a - b);
    const p = q => sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * q))];
    const seconds = values.reduce((a, b) => a + b, 0) / 1000;
    return { frames: values.length, seconds, mean_fps: values.length / seconds,
      p50_ms: p(.5), p95_ms: p(.95), p99_ms: p(.99), worst_ms: p(1),
      over_25_ms: values.filter(v => v > 25).length,
      over_50_ms: values.filter(v => v > 50).length };
  }
  if (typeof module !== 'undefined') module.exports = { summarize };
  if (typeof window === 'undefined' || new URLSearchParams(location.search).get('qa') !== '1') return;
  let context = { map: '', phase: 'title' }, running = false, last = 0, started = '', device = '';
  let totals = { city: 0, food: 0 };
  let samples = { city: [], food: [] }, trace = [], interruptions = [], contextLosses = 0;
  let traceDropped = 0, interruptionDropped = 0;
  const api = window.SinkDeviceQA = {
    enabled: true,
    state(next) {
      if (next.map !== context.map || next.phase !== context.phase || next.paused !== context.paused) last = 0;
      context = next;
      if (running) {
        if (trace.length < 3000) trace.push({ at_ms: performance.now(), ...next });
        else traceDropped++;
      }
    }
  };
  document.addEventListener('visibilitychange', () => {
    last = 0;
    if (running) {
      if (interruptions.length < 3000) interruptions.push({ at_ms: performance.now(), hidden: document.hidden });
      else interruptionDropped++;
    }
  });
  const mount = () => {
    const host = document.createElement('details');
    host.style.cssText = 'position:fixed;right:4px;top:4px;z-index:9999;max-width:230px;background:#fffef3;color:#263467;border:2px solid #6a94e3;border-radius:12px;padding:7px;font:13px system-ui;box-shadow:0 2px 6px #0005';
    host.innerHTML = '<summary>Device QA · idle</summary><p>Opt-in test save. Record 5 minutes of active play on each map, including large collapses.</p><label>Device model <input placeholder="e.g. iPhone 14" style="width:95%"></label><p><button>Start recording</button> <button disabled>Save JSON</button></p><div></div>';
    document.body.appendChild(host);
    for (const name of ['pointerdown', 'pointerup', 'touchstart', 'touchend', 'keydown']) host.addEventListener(name, e => e.stopPropagation());
    const [start, save] = host.querySelectorAll('button');
    const status = host.querySelector('summary'), metrics = host.querySelector('div');
    start.onclick = () => {
      if (!running) {
        samples = { city: [], food: [] }; totals = { city: 0, food: 0 }; trace = []; interruptions = []; contextLosses = 0; traceDropped = 0; interruptionDropped = 0;
        device = host.querySelector('input').value.trim(); started = new Date().toISOString();
      }
      running = !running; last = 0;
      start.textContent = running ? 'Stop recording' : 'Start new recording';
      save.disabled = running || !started;
      if (running) host.open = false;
    };
    save.onclick = () => {
      const report = { schema: 1, scope: 'Browser requestAnimationFrame cadence during active gameplay. Includes presentation stalls; not a direct GPU timer. Hardware model is user supplied. Visual quality and thermal acceptance require separate human review.',
        started, saved: new Date().toISOString(), device: device || 'Unspecified',
        user_agent: navigator.userAgent, device_pixel_ratio: devicePixelRatio,
        screen: [screen.width, screen.height], viewport: [innerWidth, innerHeight],
        build: window.SINK_QA_BUILD || null, context_losses: contextLosses, interruptions,
        omitted_trace_events: traceDropped, omitted_visibility_events: interruptionDropped,
        city: summarize(samples.city), food: summarize(samples.food), trace, frame_times_ms: samples,
        acceptance: 'No automatic phone PASS. Require both maps >=300 active seconds, verified device, capture review, no context loss, and sustained-frame/thermal review.' };
      const url = URL.createObjectURL(new Blob([JSON.stringify(report, null, 2)], { type: 'application/json' }));
      const link = document.createElement('a'); link.href = url; link.download = 'sink-city-device-qa.json'; link.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    };
    document.querySelector('canvas')?.addEventListener('webglcontextlost', () => { if (running) contextLosses++; });
    let frames = 0;
    function tick(now) {
      const map = context.map;
      const eligible = running && !document.hidden && context.phase === 'playing' && !context.paused && samples[map];
      if (eligible && last) {
        const elapsed = now - last;
        if (elapsed > 0) { samples[map].push(elapsed); totals[map] += elapsed; }
        if (samples.city.length + samples.food.length >= 72000) {
          running = false; save.disabled = false; start.textContent = 'Start new recording';
        }
      }
      last = eligible ? now : 0;
      if (++frames % 60 === 0) {
        status.textContent = 'Device QA · ' + (running ? (eligible ? map : 'waiting for play') : 'idle');
        metrics.textContent = ['city', 'food'].map(id => {
          const s = summarize(samples[id].slice(-120));
          return `${id}: ${(totals[id]/1000).toFixed(0)}s${s.p95_ms ? ` · P95 ${s.p95_ms.toFixed(1)} ms` : ''}`;
        }).join(' / ');
      }
      requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', mount); else mount();
})();
