// Generates the Party Cooldowns module icon: a full-colour 64x64 TGA.
// A cooldown dial (swept pie) above three party members, on a dark tile.
//   node tools/gen-partycds-icon.js
const fs = require('fs');
const path = require('path');

const N = 64, S = 4;
const OUT = path.join(__dirname, '..', 'XerionUI', 'Media', 'partycds.tga');

const ORANGE = [255, 125, 10], LIGHT = [240, 240, 240], DARK = [28, 28, 28], DIM = [70, 70, 70];

// Colour at a point, or null for transparent.
function sample(x, y) {
  // rounded tile
  const r = 10, cx = Math.min(Math.max(x, r), N - r), cy = Math.min(Math.max(y, r), N - r);
  if (Math.hypot(x - cx, y - cy) > r) return null;
  const edge = Math.min(x, y, N - x, N - y) < 2.5;
  if (edge) return ORANGE;

  // cooldown dial
  const dx = x - 32, dy = y - 24, d = Math.hypot(dx, dy);
  if (d <= 14.5 && d >= 12.5) return LIGHT;
  if (d < 12.5) {
    // angle clockwise from 12 o'clock, 0..1; the swept part is the cooldown
    let a = Math.atan2(dx, -dy) / (2 * Math.PI);
    if (a < 0) a += 1;
    return a < 0.7 ? ORANGE : DIM;
  }

  // three party members: head and shoulders
  for (const px of [16, 32, 48]) {
    if (Math.hypot(x - px, y - 45) <= 4.2) return LIGHT;
    if (y >= 51 && y <= 57 && Math.abs(x - px) <= 7 - (y - 51) * 0.45 && Math.hypot(x - px, (y - 57) * 1.4) <= 8) return LIGHT;
  }
  return DARK;
}

const buf = Buffer.alloc(18 + N * N * 4);
buf[2] = 2;                 // uncompressed true colour
buf.writeUInt16LE(N, 12);
buf.writeUInt16LE(N, 14);
buf[16] = 32;               // bits per pixel
buf[17] = 0x28;             // top-left origin, 8 alpha bits
for (let y = 0; y < N; y++) {
  for (let x = 0; x < N; x++) {
    let r = 0, g = 0, b = 0, a = 0;
    for (let sy = 0; sy < S; sy++) for (let sx = 0; sx < S; sx++) {
      const c = sample(x + (sx + 0.5) / S, y + (sy + 0.5) / S);
      if (c) { r += c[0]; g += c[1]; b += c[2]; a++; }
    }
    const o = 18 + (y * N + x) * 4;
    if (a) { buf[o] = Math.round(b / a); buf[o + 1] = Math.round(g / a); buf[o + 2] = Math.round(r / a); }
    buf[o + 3] = Math.round(255 * a / (S * S));
  }
}
fs.writeFileSync(OUT, buf);
console.log('wrote', OUT);
