#!/usr/bin/env python3
"""Carte dell'edizione italiana: ritaglia le carte dalle scansioni (pagine A4 a 300 dpi, 3x3 carte)
e le salva con i nomi usati dal gioco. Uso: python3 tools/carte_italiane.py <cartella con carte-N.jpg>
(le pagine si ottengono con: pdftoppm -r 300 -jpeg "Carte Italiano.pdf" carte)."""
import sys, os, glob
import numpy as np
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else '.'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'cards')

def runs(prof, thr, minlen):
    on = prof > thr; segs = []; s = None
    for i, v in enumerate(list(on) + [True]):
        if not v and s is None: s = i
        if v and s is not None:
            if i - s >= minlen: segs.append((s, i))
            s = None
    return segs

def crops(page):
    im = Image.open(os.path.join(SRC, 'carte-%d.jpg' % page)).convert('RGB')
    g = np.asarray(im.convert('L')).astype(float); wht = (g > 215).astype(float)
    out = []
    for y0, y1 in runs(wht.mean(1), 0.55, 400):
        for x0, x1 in runs(wht[y0:y1].mean(0), 0.55, 400):
            out.append(im.crop((x0, y0, x1, y1)))
    return out

def trim(c):
    g = np.asarray(c.convert('L')).astype(float)
    rows = np.where((g < 215).mean(1) > 0.5)[0]; cols = np.where((g < 215).mean(0) > 0.5)[0]
    return c.crop((cols[0], rows[0], cols[-1] + 1, rows[-1] + 1))

def save(c, name, w=500):
    c = trim(c); c = c.resize((w, round(c.height * w / c.width)), Image.LANCZOS)
    c.save(os.path.join(OUT, name + '.jpg'), quality=88, optimize=True)

P = {p: crops(p) for p in range(1, 10)}
prof = {1: [12, 10, 8, 7, 4, 2, 6, 1, 3], 2: [11, 9, 14, 18, 19, 15, 17, 16, 13], 3: [20, 5, 21]}
for pg, nums in prof.items():
    for i, n in enumerate(nums):
        save(P[pg][i], 'prof%02d' % n)
bonus = {5: [16, 4, 10, 18, 14, 17, 2, 9, 6], 6: [1, 11, 19, 8, 3, 5, 7, 15, 12], 7: [13, 20]}
for pg, nums in bonus.items():
    for i, n in enumerate(nums):
        save(P[pg][i], 'bonus%02d' % n)
prest = {8: [7, 6, 13, 2, 14, 4, 3, 11, 9], 9: [1, 8, 10, 5, 12]}
for pg, nums in prest.items():
    for i, n in enumerate(nums):
        save(P[pg][i], 'prest%02d' % n)
save(P[7][2], 'reclutamento')
save(P[4][6], 'dorso_professioni', 400); save(P[4][7], 'dorso_bonus', 400)
save(P[4][8], 'dorso_prestigio', 400); save(P[9][5], 'dorso_reclutamento', 400)
save(P[3][3], 'pers_banchiere'); save(P[3][5], 'pers_cardinale'); save(P[3][6], 'pers_mercante'); save(P[3][7], 'pers_professore')
# Principessa e Musa sono uscite in un unico ritaglio: si dividono a metà
pm = trim(P[3][4]); w = pm.width
save(pm.crop((0, 0, w // 2, pm.height)), 'pers_principessa'); save(pm.crop((w // 2, 0, w, pm.height)), 'pers_musa')
print('fatto')
