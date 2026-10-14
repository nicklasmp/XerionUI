// Generates the addon-list icon: a 128x128 full-colour TGA.
// A thin white X in the style of the X (Twitter) mark: one bold stroke with
// flat horizontal cuts, one hairline stroke running behind it with a gap.
//   node tools/gen-addon-icon.js [preview.png]
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const N = 128, S = 4;
const OUT = path.join(__dirname, '..', 'XerionUI', 'Media', 'addon-icon.tga');

const WHITE = [255, 255, 255], BLACK = [12, 12, 12];
const TOP = 26, BOT = 102;                  // vertical extent of the mark
const LEFT = 28, RIGHT = 100;               // horizontal extent
const BOLD = 8, HAIR = 2.6, GAP = 3.5;      // half widths (horizontal) and gap around the bold stroke
const BOLD_SHIFT = 12;                      // the bold stroke is skewed steeper than 45 degrees

// Colour at a point, or null for transparent.
function sample(x, y) {
  const r = 22, cx = Math.min(Math.max(x, r), N - r), cy = Math.min(Math.max(y, r), N - r);
  if (Math.hypot(x - cx, y - cy) > r) return null;
  if (y < TOP || y > BOT) return BLACK;
  const t = (y - TOP) / (BOT - TOP);
  const bold = (LEFT + BOLD_SHIFT) + t * (RIGHT - LEFT - 2 * BOLD_SHIFT);   // "\" centre line
  const hair = RIGHT - t * (RIGHT - LEFT);                  // "/" centre line
  if (Math.abs(x - bold) <= BOLD) return WHITE;
  if (Math.abs(x - bold) <= BOLD + GAP) return BLACK;
  if (Math.abs(x - hair) <= HAIR) return WHITE;
  return BLACK;
}
const px = new Uint8Array(N * N * 4);   // RGBA
for (let y = 0; y < N; y++) {
  for (let x = 0; x < N; x++) {
    let r = 0, g = 0, b = 0, a = 0;
    for (let sy = 0; sy < S; sy++) for (let sx = 0; sx < S; sx++) {
      const c = sample(x + (sx + 0.5) / S, y + (sy + 0.5) / S);
      if (c) { r += c[0]; g += c[1]; b += c[2]; a++; }
    }
    const o = (y * N + x) * 4;
    if (a) { px[o] = Math.round(r / a); px[o + 1] = Math.round(g / a); px[o + 2] = Math.round(b / a); }
    px[o + 3] = Math.round(255 * a / (S * S));
  }
}

const tga = Buffer.alloc(18 + N * N * 4);
tga[2] = 2;                 // uncompressed true colour
tga.writeUInt16LE(N, 12);
tga.writeUInt16LE(N, 14);
tga[16] = 32;               // bits per pixel
tga[17] = 0x28;             // top-left origin, 8 alpha bits
for (let i = 0; i < N * N; i++) {
  tga[18 + i * 4] = px[i * 4 + 2];
  tga[18 + i * 4 + 1] = px[i * 4 + 1];
  tga[18 + i * 4 + 2] = px[i * 4];
  tga[18 + i * 4 + 3] = px[i * 4 + 3];
}
fs.writeFileSync(OUT, tga);
console.log('wrote', OUT);

// Optional PNG preview for eyeballing (not shipped).
if (process.argv[2]) {
  const crcTable = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
  const crc = (buf) => { let c = 0xffffffff; for (const v of buf) c = crcTable[(c ^ v) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
  const chunk = (type, data) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const td = Buffer.concat([Buffer.from(type), data]);
    const c = Buffer.alloc(4); c.writeUInt32BE(crc(td));
    return Buffer.concat([len, td, c]);
  };
  const raw = Buffer.alloc((N * 4 + 1) * N);
  for (let y = 0; y < N; y++) { raw[y * (N * 4 + 1)] = 0; Buffer.from(px.buffer, y * N * 4, N * 4).copy(raw, y * (N * 4 + 1) + 1); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(N, 0); ihdr.writeUInt32BE(N, 4); ihdr[8] = 8; ihdr[9] = 6;
  fs.writeFileSync(process.argv[2], Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
}
