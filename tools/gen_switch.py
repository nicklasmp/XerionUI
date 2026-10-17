# Generates pixel-exact switch textures (white + alpha) for the options toggle.
# Each shape sits in the top-left of a power-of-two canvas and is drawn 1:1.
import struct, math, os
OUT = os.path.join(os.path.dirname(__file__), "..", "XerionUI", "Media")
SS = 8

def tga(name, cw, ch, w, h, inside):
    px = bytearray()
    for y in range(ch):
        for x in range(cw):
            a = 0
            if x < w and y < h:
                n = 0
                for sy in range(SS):
                    for sx in range(SS):
                        if inside(x + (sx + .5) / SS, y + (sy + .5) / SS): n += 1
                a = round(255 * n / SS / SS)
            px += bytes((255, 255, 255, a))
    hdr = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, cw, ch, 32, 0x28)
    open(os.path.join(OUT, name), "wb").write(hdr + bytes(px))

def pill(w, h):
    r = h / 2
    def f(x, y):
        cx = min(max(x, r), w - r)
        return (x - cx) ** 2 + (y - r) ** 2 <= r * r
    return f

for w, h in ((34, 18), (30, 16)):
    tga("switch%dx%d.tga" % (w, h), 64, 32, w, h, pill(w, h))
for d in (14, 12):
    tga("knob%d.tga" % d, 16, 16, d, d, pill(d, d))
