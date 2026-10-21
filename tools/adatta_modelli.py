"""Adatta i modelli Meshy alla sagoma esatta della tessera.
Per ogni modello: orientamento migliore (4 rotazioni x specchio) confrontando l'impronta della base
con la sagoma; scala in X/Z fino a riempire il riquadro della sagoma (in caselle); toglie la base
del modello (la tessera di cartone la sostituisce) e i triangoli fuori dalla sagoma.
Uscita: GLB in unità di casella, centrato sul centro del riquadro, base a y=0."""
import sys, io, json, numpy as np, trimesh
from PIL import Image, ImageDraw
sys.path.insert(0, '/home/claude/meshy_ws')
from process import write_glb
SH = {
 "universita": ["##.", "###", ".##"], "laboratorio": ["##.", "###", "#.#"], "bottega": ["###", "###", "..#"],
 "biblioteca": [".#.", "###", "#.."], "opera": ["###", "#..", "#.."], "studio": ["###", "#.#"],
 "ospedale": ["..#", "###", "#.."], "teatro": [".###", "##.."], "torre": ["#.", "##"], "cappella": ["#", "#", "#"],
 "bosco": [".##", "###"], "palazzo": ["###", "###"], "lago": ["##", "##"], "parco": ["#", "#", "#"]}

def cells(nm):
    return {(x, y) for y, row in enumerate(SH[nm]) for x, ch in enumerate(row) if ch == '#'}

def inside(nm, x, z, margin=0.0):
    c = cells(nm)
    xi = np.floor(x).astype(int); zi = np.floor(z).astype(int)
    ok = np.array([(a, b) in c for a, b in zip(xi, zi)])
    if margin > 0:
        for dx in (-margin, margin):
            for dz in (-margin, margin):
                xi2 = np.floor(x + dx).astype(int); zi2 = np.floor(z + dz).astype(int)
                ok |= np.array([(a, b) in c for a, b in zip(xi2, zi2)])
    return ok

def transform(V, rot, mirror):
    x, y, z = V[:, 0].copy(), V[:, 1].copy(), V[:, 2].copy()
    if mirror:
        x = -x
    for _ in range(rot):   # 90° in senso orario visto dall'alto (x destra, z giù)
        x, z = -z, x
    return np.stack([x, y, z], 1)

def fit(nm, cut_frac=None, report=True):
    m = trimesh.load(f'/home/claude/meshy_ws/proc/{nm}.glb', force='mesh', process=False)
    V = m.vertices.copy(); F = m.faces.copy(); UV = m.visual.uv.copy()
    img = m.visual.material.baseColorTexture.convert('RGB')
    W0 = len(SH[nm][0]); H0 = len(SH[nm])
    y = V[:, 1]; ymin, ymax = y.min(), y.max(); hgt = ymax - ymin
    CUT = {'universita': 0.06}
    base_cut = ymin + (cut_frac if cut_frac is not None else CUT.get(nm, 0.06)) * hgt
    low = F[(y[F].max(1) <= ymin + 0.3 * hgt)]
    best = None
    for mirror in (False, True):
        for rot in range(4):
            P = transform(V, rot, mirror)
            mn = P[:, [0, 2]].min(0); ext = P[:, [0, 2]].max(0) - mn
            Q = (P[:, [0, 2]] - mn) / ext * np.array([W0, H0])
            res = 24
            im = Image.new('L', (W0 * res, H0 * res), 0); d = ImageDraw.Draw(im)
            for f in low:
                d.polygon([(Q[i, 0] * res, Q[i, 1] * res) for i in f], fill=255)
            o = np.asarray(im) > 0
            mask = np.zeros_like(o)
            for (cx, cz) in cells(nm):
                mask[cz * res:(cz + 1) * res, cx * res:(cx + 1) * res] = True
            iou = (o & mask).sum() / max(1, (o | mask).sum())
            asp = abs(np.log((ext[0] / ext[1]) / (W0 / H0)))
            score = iou - 0.3 * asp
            if best is None or score > best[0]:
                best = (score, rot, mirror, iou, asp)
    _, rot, mirror, iou, asp = best
    FORCE = {'torre': (0, False), 'palazzo': (0, False), 'universita': (3, True)}
    if nm in FORCE:
        rot, mirror = FORCE[nm]
    P = transform(V, rot, mirror)
    mn = P[:, [0, 2]].min(0); ext = P[:, [0, 2]].max(0) - mn
    sx = W0 / ext[0]; sz = H0 / ext[1]; sy = min(sx, sz)
    X = (P[:, 0] - mn[0]) * sx; Z = (P[:, 2] - mn[1]) * sz; Y = (P[:, 1] - base_cut) * sy
    N = np.stack([X, Y, Z], 1)
    if mirror:
        F = F[:, ::-1]
    # via la base e tutto ciò che sta fuori dalla sagoma
    cen = N[F].mean(1)
    keep = (N[F][:, :, 1].max(1) > 0.0) & inside(nm, cen[:, 0], cen[:, 2], 0.02)
    F2 = F[keep]
    N[:, 1] = np.maximum(N[:, 1], 0.0)
    N[:, 0] = np.clip(N[:, 0], 0, W0); N[:, 2] = np.clip(N[:, 2], 0, H0)
    used = np.unique(F2)
    remap = -np.ones(len(N), int); remap[used] = np.arange(len(used))
    N2 = N[used]; UV2 = UV[used]; F3 = remap[F2]
    N2 = N2 - np.array([W0 / 2.0, 0, H0 / 2.0])
    mm = trimesh.Trimesh(N2, F3, process=False)
    write_glb(f'/home/claude/meshy_ws/fit/{nm}.glb', N2, F3, UV2, mm.vertex_normals, img.resize((1024, 1024)))
    if report:
        print(nm, 'rot', rot, 'mirror', mirror, 'iou %.2f asp %.2f' % (iou, asp), 'facce', len(F3), 'altezza %.2f' % N2[:, 1].max(), flush=True)
    return rot, mirror

if __name__ == '__main__':
    out = {}
    for nm in sys.argv[1:] or list(SH):
        out[nm] = fit(nm)
