/* Original store composition around intact, verified physical-iPhone frames. */
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require(process.env.HOLE_FEAST_SHARP_MODULE || 'sharp');
const root = path.resolve(__dirname, '..');
const out = path.join(root, 'artifacts/app-store-release-20261001/screenshots');
const frames = path.join(root, 'artifacts/device-acceptance-20261001-06/native-qa');
const cards = [
  {id:'01-black-hole-food-city', frame:'food-01.png', lines:['BLACK HOLE.', 'BIG APPETITE.'], benefit:'SWALLOW A FOOD CITY', accent:'#ffcf60'},
  {id:'02-eat-grow', frame:'food-04.png', lines:['BITE. GROW.', 'DEVOUR.'], benefit:'60 SECOND FEASTS', accent:'#97ead8'},
  {id:'04-swallow-city', frame:'city-03.png', lines:['EAT YOUR WAY', 'THROUGH TOWN.'], benefit:'TWO WORLDS TO DEVOUR', accent:'#9adbf5'}
];
const sha = data => crypto.createHash('sha256').update(data).digest('hex');
const escape = s => s.replaceAll('&','&amp;').replaceAll('<','&lt;');
async function main() {
  fs.mkdirSync(out, {recursive:true});
  const manifest = [];
  for (const card of cards) {
    const source = path.join(frames,card.frame);
    const frame = fs.readFileSync(source);
    const meta = await sharp(frame).metadata();
    if (meta.width !== 1320 || meta.height !== 2868) throw new Error('Unexpected physical-iPhone frame dimensions');
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1320" height="2868" viewBox="0 0 1320 2868">
      <defs><linearGradient id="bg" x2=".8" y2="1"><stop stop-color="#17264c"/><stop offset="1" stop-color="#493d87"/></linearGradient><clipPath id="screen"><rect x="177" y="588" width="966" height="2098.8" rx="46"/></clipPath></defs>
      <rect width="1320" height="2868" fill="url(#bg)"/>
      <circle cx="1270" cy="90" r="360" fill="none" stroke="${card.accent}" stroke-width="38" opacity=".1"/>
      <circle cx="40" cy="2630" r="430" fill="none" stroke="#9adbf5" stroke-width="32" opacity=".08"/>
      <rect x="89" y="84" width="300" height="66" rx="33" fill="#ffffff" opacity=".1"/>
      <text x="239" y="129" text-anchor="middle" fill="#fffaf0" font-family="Avenir Next,Arial,sans-serif" font-size="29" font-weight="700" letter-spacing="4">HOLE FEAST</text>
      <g fill="#fffaf0" font-family="Avenir Next,Arial,sans-serif" font-size="112" font-weight="900" letter-spacing="-3"><text x="86" y="297">${escape(card.lines[0])}</text><text x="86" y="427">${escape(card.lines[1])}</text></g>
      <rect x="89" y="471" width="780" height="69" rx="34" fill="${card.accent}"/>
      <text x="479" y="516" text-anchor="middle" fill="#17264c" font-family="Avenir Next,Arial,sans-serif" font-size="29" font-weight="800" letter-spacing="2">${escape(card.benefit)}</text>
      <rect x="161" y="574" width="998" height="2130" rx="60" fill="#080f25" opacity=".45"/><rect x="166" y="577" width="988" height="2122" rx="56" fill="#fffaf0"/>
      <image href="data:image/png;base64,${frame.toString('base64')}" x="177" y="588" width="966" height="2098.8" preserveAspectRatio="xMidYMid meet" clip-path="url(#screen)"/>
      <text x="660" y="2786" text-anchor="middle" fill="#d8d7f1" font-family="Avenir Next,Arial,sans-serif" font-size="24" letter-spacing="4">EAT · GROW · FEAST</text>
    </svg>`;
    fs.writeFileSync(path.join(out,card.id+'.svg'),svg);
    const png = await sharp(Buffer.from(svg)).flatten({background:'#17264c'}).png().toBuffer();
    fs.writeFileSync(path.join(out,card.id+'.png'),png);
    manifest.push({id:card.id, source:path.relative(root,source),source_sha256:sha(frame),png_sha256:sha(png),width:1320,height:2868,native_capture:true,game_pixels:'Intact actual 0.12.3 build 6 viewport frame, uniformly scaled into an original decorative frame.',reviewed_for_notifications:true,ready_for_upload:true,uploaded:false});
  }
  const thumbs = await Promise.all(cards.map(card=>sharp(path.join(out,card.id+'.png')).resize(330,717).toBuffer()));
  await sharp({create:{width:cards.length*330,height:717,channels:3,background:'#17264c'}}).composite(thumbs.map((input,i)=>({input,left:i*330,top:0}))).png().toFile(path.join(out,'contact-sheet.png'));
  fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify({scope:'Original US App Store composition; actual physical-iPhone 0.12.3 gameplay. No invented gameplay, score, ownership or competitor assets.',cards:manifest,remaining:['Current native Sushi Express frame','Current native unified collection frame'],uploaded:false},null,2)+'\n');
  console.log(JSON.stringify({cards:manifest.length,directory:path.relative(root,out)}));
}
main().catch(error=>{console.error(error);process.exitCode=1});
