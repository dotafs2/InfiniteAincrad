/* Original SVG composition around unchanged gameplay pixels. Layout review
 * only: replace desktop captures with accepted native frames before upload. */
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require(process.env.HOLE_FEAST_SHARP_MODULE || 'sharp');
const root = path.resolve(__dirname, '..');
const out = path.join(root, 'artifacts/native-polish-20261001/store-drafts');
const frames = path.join(root, 'artifacts/native-polish-20261001/visual-03');
const gallery = path.join(root, 'artifacts/native-polish-20261001/store-gallery');
const cards = [
  {id:'01-food-city', frame:'food-40.png', lines:['BLACK HOLE.', 'BIG APPETITE.'], benefit:'SWALLOW A FOOD CITY', accent:'#ffcf60'},
  {id:'02-growth', frame:'food-58.png', lines:['BITE. GROW.', 'DEVOUR.'], benefit:'60 SECOND FEASTS', accent:'#97ead8'},
  {id:'03-sushi-express', directory:gallery, frame:'sushi-express-1.png', lines:['SUSHI.', 'ON THE MOVE.'], benefit:'CHASE THE SUSHI EXPRESS', accent:'#ffaaa7'},
  {id:'04-city', directory:gallery, frame:'city-40.png', lines:['EAT YOUR WAY', 'THROUGH TOWN.'], benefit:'GROW FROM SMALL TO HUGE', accent:'#9adbf5'},
  {id:'05-skins', directory:gallery, frame:'skins-classic-3.png', lines:['A FEAST', 'OF STYLES.'], benefit:'COLLECT ORIGINAL HOLE SKINS', accent:'#c9b2ff'}
];
const sha = data => crypto.createHash('sha256').update(data).digest('hex');
const escape = s => s.replaceAll('&','&amp;').replaceAll('<','&lt;');
async function main() {
  fs.mkdirSync(out, {recursive:true});
  const manifest = [];
  for (const card of cards) {
    const source = path.join(card.directory || frames,card.frame);
    const frame = fs.readFileSync(source);
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1320" height="2868" viewBox="0 0 1320 2868">
      <defs>
        <linearGradient id="bg" x2=".8" y2="1"><stop stop-color="#17264c"/><stop offset="1" stop-color="#493d87"/></linearGradient>
        <clipPath id="screen"><rect x="177" y="588" width="966" height="2100" rx="46"/></clipPath>
      </defs>
      <rect width="1320" height="2868" fill="url(#bg)"/>
      <circle cx="1270" cy="90" r="360" fill="none" stroke="${card.accent}" stroke-width="38" opacity=".1"/>
      <circle cx="40" cy="2630" r="430" fill="none" stroke="#9adbf5" stroke-width="32" opacity=".08"/>
      <rect x="89" y="84" width="300" height="66" rx="33" fill="#ffffff" opacity=".1"/>
      <text x="239" y="129" text-anchor="middle" fill="#fffaf0" font-family="Avenir Next,Arial,sans-serif" font-size="29" font-weight="700" letter-spacing="4">HOLE FEAST</text>
      <g fill="#fffaf0" font-family="Avenir Next,Arial,sans-serif" font-size="112" font-weight="900" letter-spacing="-3">
        <text x="86" y="297">${escape(card.lines[0])}</text>
        <text x="86" y="427">${escape(card.lines[1])}</text>
      </g>
      <rect x="89" y="471" width="750" height="69" rx="34" fill="${card.accent}"/>
      <text x="464" y="516" text-anchor="middle" fill="#17264c" font-family="Avenir Next,Arial,sans-serif" font-size="29" font-weight="800" letter-spacing="2">${escape(card.benefit)}</text>
      <rect x="161" y="574" width="998" height="2130" rx="60" fill="#080f25" opacity=".45"/>
      <rect x="166" y="577" width="988" height="2122" rx="56" fill="#fffaf0"/>
      <image href="data:image/png;base64,${frame.toString('base64')}" x="177" y="588" width="966" height="2100" preserveAspectRatio="xMidYMid meet" clip-path="url(#screen)"/>
      <text x="660" y="2786" text-anchor="middle" fill="#d8d7f1" font-family="Arial,sans-serif" font-size="24" letter-spacing="2">LAYOUT DRAFT · DESKTOP GAMEPLAY CAPTURE</text>
    </svg>`;
    fs.writeFileSync(path.join(out,card.id+'.svg'),svg);
    const png = await sharp(Buffer.from(svg)).png().toBuffer();
    fs.writeFileSync(path.join(out,card.id+'.png'),png);
    manifest.push({id:card.id, source:path.relative(root,source), source_sha256:sha(frame), png_sha256:sha(png), width:1320, height:2868, native_capture:false, ready_for_upload:false});
  }
  const thumbs = await Promise.all(cards.map(card=>sharp(path.join(out,card.id+'.png')).resize(330,717).toBuffer()));
  await sharp({create:{width:cards.length*330,height:717,channels:3,background:'#17264c'}}).composite(thumbs.map((input,i)=>({input,left:i*330,top:0}))).png().toFile(path.join(out,'contact-sheet.png'));
  fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify({scope:'Original composition, unchanged actual game frames. Explicit desktop layout drafts, not uploadable native screenshots.',cards:manifest},null,2)+'\n');
  console.log(JSON.stringify({cards:manifest.length, ready_for_upload:false, directory:path.relative(root,out)}));
}
main().catch(error=>{console.error(error);process.exitCode=1});
