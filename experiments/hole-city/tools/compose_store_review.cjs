/* REVIEW V1: original composition around intact, actual Mac gameplay frames. */
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require(process.env.HOLE_FEAST_SHARP_MODULE || 'sharp');
const root = path.resolve(__dirname, '..');
const base = path.join(root, 'artifacts/store-review-20261001-v1');
const out = path.join(base, 'screenshots');
const cards = [
  {id:'01-black-hole-food-city', frame:'captures/food-25.png', lines:['BLACK HOLE.', 'BIG APPETITE.'], benefit:'SWALLOW A FOOD CITY', accent:'#ffcf60', caption:'A food city, made for your appetite.'},
  {id:'02-eat-grow', frame:'captures/food-drop-572.png', lines:['BITE. GROW.', 'DEVOUR.'], benefit:'WATCH THE STACKS FALL', accent:'#97ead8', caption:'Start small. Grow into towering stacks.'},
  {id:'03-sushi-express', frame:'feature-captures/sushi-midpoint-3.png', lines:['SUSHI.', 'ON THE MOVE.'], benefit:'CHASE THE SUSHI EXPRESS', accent:'#ffc0ba', caption:'A moving sushi train to chase and devour.'},
  {id:'04-swallow-city', frame:'captures/city-drop-553.png', lines:['EAT YOUR WAY', 'THROUGH TOWN.'], benefit:'SWALLOW THE CITY', accent:'#9adbf5', caption:'From street objects to bigger city targets.'},
  {id:'05-original-skins', frame:'feature-captures/collection-selected-cake.png', lines:['A FEAST', 'OF STYLES.'], benefit:'44 ORIGINAL HOLE SKINS', accent:'#dbbcff', caption:'One scrolling collection. Common to Prismatic.'}
];
const sha = data => crypto.createHash('sha256').update(data).digest('hex');
const esc = s => s.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');

async function main() {
  fs.mkdirSync(out, {recursive:true});
  const manifest = [];
  for (const card of cards) {
    const source = path.join(base, card.frame);
    const frame = fs.readFileSync(source);
    const meta = await sharp(frame).metadata();
    if (!((meta.width===1320 && meta.height===2868) || (meta.width===886 && meta.height===1920))) throw new Error('Unexpected actual viewport dimensions');
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1320" height="2868" viewBox="0 0 1320 2868">
      <defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#17264c"/><stop offset="1" stop-color="#493d87"/></linearGradient><clipPath id="screen"><rect x="177" y="588" width="966" height="2098.8" rx="46"/></clipPath></defs>
      <rect width="1320" height="2868" fill="url(#bg)"/>
      <circle cx="1270" cy="90" r="360" fill="none" stroke="${card.accent}" stroke-width="38" opacity=".1"/>
      <circle cx="40" cy="2630" r="430" fill="none" stroke="#9adbf5" stroke-width="32" opacity=".08"/>
      <rect x="89" y="84" width="300" height="66" rx="33" fill="#ffffff" opacity=".1"/>
      <text x="239" y="129" text-anchor="middle" fill="#fffaf0" font-family="Avenir Next,Arial,sans-serif" font-size="29" font-weight="700" letter-spacing="4">HOLE FEAST</text>
      <g fill="#fffaf0" font-family="Avenir Next,Arial,sans-serif" font-size="112" font-weight="900" letter-spacing="-3"><text x="86" y="297">${esc(card.lines[0])}</text><text x="86" y="427">${esc(card.lines[1])}</text></g>
      <rect x="89" y="471" width="780" height="69" rx="34" fill="${card.accent}"/>
      <text x="479" y="516" text-anchor="middle" fill="#17264c" font-family="Avenir Next,Arial,sans-serif" font-size="29" font-weight="800" letter-spacing="2">${esc(card.benefit)}</text>
      <rect x="161" y="574" width="998" height="2130" rx="60" fill="#080f25" opacity=".45"/>
      <rect x="166" y="577" width="988" height="2122" rx="56" fill="#fffaf0"/>
      <image href="data:image/png;base64,${frame.toString('base64')}" x="177" y="588" width="966" height="2098.8" preserveAspectRatio="xMidYMid meet" clip-path="url(#screen)"/>
      <text x="660" y="2786" text-anchor="middle" fill="#d8d7f1" font-family="Avenir Next,Arial,sans-serif" font-size="24" letter-spacing="4">EAT · GROW · FEAST</text>
    </svg>`;
    fs.writeFileSync(path.join(out,card.id+'.svg'),svg);
    const png = await sharp(Buffer.from(svg)).flatten({background:'#17264c'}).png().toBuffer();
    const rendered = await sharp(png).metadata();
    if (rendered.width!==1320 || rendered.height!==2868 || rendered.hasAlpha) throw new Error('Composition export failed');
    fs.writeFileSync(path.join(out,card.id+'.png'),png);
    manifest.push({id:card.id,source:path.relative(root,source),source_sha256:sha(frame),source_width:meta.width,source_height:meta.height,png_sha256:sha(png),width:1320,height:2868,has_alpha:false,physical_iphone_capture:false,game_pixels:'Intact actual 0.12.3 Mac viewport; uniform scaling in an original decorative frame. No added props, drop effects, score, entitlements or scene rearrangement.',review_ready:true,uploaded:false});
  }
  const thumbs = await Promise.all(cards.map(card=>sharp(path.join(out,card.id+'.png')).resize(330,717).toBuffer()));
  await sharp({create:{width:1650,height:717,channels:3,background:'#17264c'}}).composite(thumbs.map((input,i)=>({input,left:i*330,top:0}))).png().toFile(path.join(out,'contact-sheet.png'));
  await sharp(path.join(root,'icon.svg')).resize(256,256).flatten({background:'#17264c'}).png().toFile(path.join(base,'icon.png'));
  fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify({scope:'Review V1 authorized from Mac gameplay. Five original US store compositions; food stacks and city objects visibly entering the actual game hole. No competitor assets.',game_version:'0.12.3',cards:manifest,review_ready:true,uploaded:false},null,2)+'\n');
  fs.copyFileSync(path.join(root,'docs/app-store-release-20261001/store-copy.md'),path.join(base,'store-copy.md'));
  fs.writeFileSync(path.join(base,'index.html'),html());
  console.log(JSON.stringify({cards:manifest.length,directory:path.relative(root,base),review_ready:true,uploaded:false}));
}

function html() {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Hole Feast — Store Review V1</title>
  <style>
  *{box-sizing:border-box}body{margin:0;color:#17264c;background:#faf8f3;font:16px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}a{color:inherit}header{border-bottom:1px solid #e8e2d8;background:#fffdf9}.wrap{max-width:1340px;margin:auto;padding:42px 36px}.brand{display:flex;gap:24px;align-items:center}.icon{width:106px;height:106px;border-radius:24px;box-shadow:0 6px 18px #17264c18}.eyebrow{font-size:12px;letter-spacing:.18em;text-transform:uppercase;font-weight:800;color:#766389}h1{font-size:clamp(27px,3vw,43px);letter-spacing:-.045em;line-height:1.15;margin:8px 0}p{margin:8px 0}.sub{color:#746d7d}.button{display:inline-flex;border:0;border-radius:50px;background:#17264c;color:#fffaf0;padding:12px 21px;font-weight:700;text-decoration:none;cursor:pointer;font-size:14px}.secondary{background:#ece8f6;color:#493d87}.actions{display:flex;gap:12px;flex-wrap:wrap;margin-top:21px}.section-heading{display:flex;align-items:end;justify-content:space-between;gap:20px;margin-bottom:23px}h2{font-size:29px;letter-spacing:-.03em;margin:0}.badge{display:inline-block;border-radius:30px;background:#e8f4ec;color:#226044;padding:4px 11px;font-size:12px;font-weight:700}.video-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px}.video-card{padding:24px;background:#eee9e2;border:1px solid #e6dfd5;border-radius:24px;display:grid;grid-template-columns:minmax(0,1fr) minmax(0,250px);gap:22px;align-items:center}.video-card h3{font-size:27px;line-height:1.15;letter-spacing:-.03em;margin:10px 0}.video-card p{font-size:14px;color:#655f70}.video-card video{width:100%;height:auto;aspect-ratio:886/1920;background:#17264c;border-radius:17px;display:block;box-shadow:0 8px 24px #17264c25}.video-actions{display:flex;gap:8px;flex-direction:column;margin-top:20px}.video-actions button{padding:11px 12px}.download{display:block;font-size:12px;font-weight:700;margin-top:12px;color:#493d87}.gallery{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:17px}.shot-button{display:block;width:100%;padding:0;background:none;border:0;cursor:zoom-in;border-radius:16px;overflow:hidden;box-shadow:0 6px 20px #17264c15}.shot-button img{display:block;width:100%;height:auto}.shot-caption{font-size:13px;margin:13px 0 5px;font-weight:700}.shot-number{color:#8b8195;font-size:11px;letter-spacing:.12em}.copy{background:white;border:1px solid #e8e2d8;border-radius:22px;padding:27px;display:grid;grid-template-columns:1fr 1fr;gap:35px;margin-top:42px}.copy h3{font-size:14px;letter-spacing:.08em;text-transform:uppercase;color:#8b8195;margin:0 0 8px}.copy p{max-width:620px}.copy ul{padding-left:20px;color:#655f70;margin-bottom:0}.notes{font-size:12px;color:#817a87;padding-bottom:35px}dialog{padding:12px;border:0;border-radius:20px;background:#faf8f3;max-width:96vw;max-height:95vh}dialog::backdrop{background:#0b122cbb}dialog img{display:block;max-height:81vh;max-width:87vw;width:auto;margin:auto;border-radius:10px}dialog .actions{justify-content:space-between;margin:10px 0 0}footer{border-top:1px solid #e8e2d8}
  @media(max-width:1100px){.video-card{grid-template-columns:1fr 180px}.wrap{padding:30px 24px}.video-card{padding:18px;gap:16px}}@media(max-width:760px){.brand{gap:16px}.icon{width:75px;height:75px;border-radius:17px}.wrap{padding:28px 18px}.video-grid{grid-template-columns:1fr}.video-card{grid-template-columns:1fr minmax(0,200px)}.gallery{display:flex;overflow:auto;scroll-snap-type:x mandatory;padding:5px 0 16px}.gallery article{min-width:220px;scroll-snap-align:start}.copy{grid-template-columns:1fr;gap:22px;padding:22px}.section-heading{display:block}.section-heading .sub{font-size:14px}.video-card h3{font-size:24px}}@media(max-width:400px){.video-card{grid-template-columns:1fr 150px;gap:12px}.video-card p{font-size:12px}}
  </style></head><body>
  <header><div class="wrap"><div class="brand"><img class="icon" src="icon.png" alt="Hole Feast app icon"><div><div class="eyebrow">United States · Store Review V1</div><h1>Black Hole Feast: Eat &amp; Grow</h1><p class="sub">Swallow Cities &amp; Tasty Treats</p><span class="badge">5 screenshots · 2 videos</span></div></div><div class="actions"><a class="button" href="Hole-Feast-Store-Review-V1.zip" download>Download the review pack</a><a class="button secondary" href="#screenshots">View screenshots</a><a class="button secondary" href="store-copy.md" download>Store copy</a></div></div></header>
  <main class="wrap"><div class="section-heading"><div><div class="eyebrow">App previews</div><h2>Watch the world fall in.</h2></div><p class="sub">Actual gameplay · 20 seconds each · Sound off by default</p></div>
  <div class="video-grid">
    <article class="video-card"><div><div class="eyebrow">01 / Snack Garden</div><h3>Small bites.<br>Giant feasts.</h3><p>Grow from little treats to food stacks that collapse into your black hole.</p><div class="video-actions"><button class="button play" data-video="food">Play silently</button><button class="button secondary sound" data-video="food" aria-pressed="false">Sound on</button></div><a class="download" href="videos/01-food-feast.mp4" download>Download food video ↓</a></div><video id="food" muted controls playsinline preload="metadata" poster="videos/food-poster.png"><source src="videos/01-food-feast.mp4" type="video/mp4"></video></article>
    <article class="video-card"><div><div class="eyebrow">02 / Sunny City</div><h3>A city.<br>One hungry hole.</h3><p>Swallow street objects, trees and larger targets as your appetite grows.</p><div class="video-actions"><button class="button play" data-video="city">Play silently</button><button class="button secondary sound" data-video="city" aria-pressed="false">Sound on</button></div><a class="download" href="videos/02-city-swallow.mp4" download>Download city video ↓</a></div><video id="city" muted controls playsinline preload="metadata" poster="videos/city-poster.png"><source src="videos/02-city-swallow.mp4" type="video/mp4"></video></article>
  </div>
  <section id="screenshots" style="margin-top:52px"><div class="section-heading"><div><div class="eyebrow">Screenshots / proposed order</div><h2>One appetite. More to discover.</h2></div><p class="sub">Click any image to review it at full size.</p></div><div class="gallery">${cards.map((card,i)=>`<article><button class="shot-button" data-source="screenshots/${card.id}.png" aria-label="Open screenshot ${i+1}: ${esc(card.caption)}"><img src="screenshots/${card.id}.png" alt="${esc(card.lines.join(' '))}"></button><p class="shot-caption">${esc(card.caption)}</p><span class="shot-number">0${i+1} / 1320 × 2868</span><a class="download" href="screenshots/${card.id}.png" download>Download PNG ↓</a></article>`).join('')}</div></section>
  <div class="copy"><div><h3>Promotional text</h3><p>One minute. One hungry hole. Swallow a colorful food city, grow through giant stacks, and chase the Sushi Express. Explore Sunny City and collect original skins.</p></div><div><h3>What the images communicate</h3><ul><li>Swallow food and city objects. Grow into bigger targets.</li><li>Two playable worlds, a moving sushi train, and 60-second rounds.</li><li>44 original skins in one scrolling collection.</li></ul></div></div>
  </main><footer><div class="wrap notes">Review V1 · Hole Feast 0.12.3 · Captured from the actual game on Mac. Original captions and frames surround intact gameplay; videos use normal-speed chronological cuts and game audio. Store upload and review submission are pending.</div></footer>
  <dialog id="lightbox"><img id="fullshot" alt="Full-size store screenshot"><div class="actions"><a class="button" id="full-download" download>Download PNG</a><button class="button secondary" id="close">Close</button></div></dialog>
  <script>
  const box=document.getElementById('lightbox');document.querySelectorAll('.shot-button').forEach(button=>button.addEventListener('click',()=>{document.getElementById('fullshot').src=button.dataset.source;document.getElementById('full-download').href=button.dataset.source;box.showModal()}));document.getElementById('close').addEventListener('click',()=>box.close());box.addEventListener('click',event=>{if(event.target===box)box.close()});
  document.querySelectorAll('.play').forEach(button=>button.addEventListener('click',()=>{const video=document.getElementById(button.dataset.video);document.querySelectorAll('video').forEach(other=>{if(other!==video)other.pause()});if(video.paused){video.play().catch(()=>{});button.textContent='Pause'}else{video.pause();button.textContent=video.muted?'Play silently':'Play'}}));document.querySelectorAll('.sound').forEach(button=>button.addEventListener('click',()=>{const video=document.getElementById(button.dataset.video);video.muted=!video.muted;button.textContent=video.muted?'Sound on':'Sound off';button.setAttribute('aria-pressed',String(!video.muted))}));document.querySelectorAll('video').forEach(video=>{const button=document.querySelector('.play[data-video="'+video.id+'"]');video.addEventListener('play',()=>{button.textContent='Pause'});video.addEventListener('pause',()=>{button.textContent=video.muted?'Play silently':'Play'});video.addEventListener('ended',()=>{button.textContent=video.muted?'Play again silently':'Play again'})});
  </script></body></html>`;
}
main().catch(error=>{console.error(error);process.exitCode=1});
