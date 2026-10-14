// Generates the addon-list icon: a 128x128 full-colour TGA.
// A woven X (orange blade over a pale blade) on a dark rounded tile with a soft glow.
//   node tools/gen-addon-icon.js [preview.png]
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const N = 128, S = 4;
const OUT = path.join(__dirname, '..', 'XerionUI', 'Media', 'addon-icon.tga');

const ORANGE = [255, 125, 10], AMBER = [255, 190, 60], PALE = [236, 238, 244], PALE_LO = [150, 156, 172];
const BG_TOP = [34, 34, 38], BG_BOT = [14, 14, 16];

const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
const clamp01 = (t) => Math.min(Math.max(t, 0), 1);

// distance from (x,y) to the segment a-b
function segDist(x, y, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay;
  const t = clamp01(((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy));
  return Math.hypot(x - (ax + t * dx), y - (ay + t * dy));
}

const LO = 31, HI = 97, HALF = 9.5;          // blade extents and half thickness
function bladeA(x, y) { return segDist(x, y, LO, LO, HI, HI); }   // "\"
function bladeB(x, y) { return segDist(x, y, HI, LO, LO, HI); }   // "/"

// Colour at a point, or null for transparent.
function sample(x, y) {
  const r = 22, cx = Math.min(Math.max(x, r), N - r), cy = Math.min(Math.max(y, r), N - r);
  if (Math.hypot(x - cx, y - cy) > r) return null;

  const edge = Math.min(x, y, N - x, N - y);
  const dB = bladeB(x, y), dA = bladeA(x, y);

  // pale blade "/" on top, with a dark keyline where it crosses the orange one
  if (dB <= HALF) return mix(PALE, PALE_LO, clamp01((x + y - 60) / 110));
  if (dB <= HALF + 3.5 && dA <= HALF) return BG_BOT;

  // orange blade "\" with a bright-to-deep gradient along its length
  if (dA <= HALF) return mix(AMBER, ORANGE, clamp01((x + y - 62) / 80));

  // rim light
  if (edge < 3) return mix(ORANGE, [150, 60, 0], clamp01((y) / N));

  // background: vertical gradient plus a warm glow around the X
  let c = mix(BG_TOP, BG_BOT, y / N);
  const glow = Math.exp(-Math.min(dA, dB) / 15) * 0.5;
  return mix(c, ORANGE, glow * 0.55);
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
