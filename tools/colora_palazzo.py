"""Palazzo: modello senza colori (Meshy) + colori proiettati dall'alto dall'illustrazione della plancia.
Facce rivolte in alto: illustrazione; pareti: intonaco chiaro con fascia rossa, come nel riferimento."""
import sys, numpy as np, trimesh, pymeshlab, io
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0,'/home/claude/meshy_ws')
from process import write_glb
W0,H0=3,2
src=trimesh.load('/home/claude/meshy_ws/m3d/palazzo.glb',force='mesh',process=False)
ms=pymeshlab.MeshSet(); ms.add_mesh(pymeshlab.Mesh(src.vertices,src.faces))
ms.meshing_remove_duplicate_vertices()
ms.meshing_decimation_quadric_edge_collapse(targetfacenum=16000,qualitythr=0.5,preserveboundary=True,optimalplacement=True)
mm=ms.current_mesh(); V=mm.vertex_matrix(); F=mm.face_matrix()
best=None
for rot in range(4):
    P=V.copy(); x,y,z=P[:,0].copy(),P[:,1].copy(),P[:,2].copy()
    for _ in range(rot): x,z=-z,x
    ext=np.array([x.max()-x.min(),z.max()-z.min()])
    asp=abs(np.log((ext[0]/ext[1])/1.5))
    X=(x-x.min())/ext[0]*W0; Z=(z-z.min())/ext[1]*H0
    top=np.argmax(y); hz=Z[top]
    score=-asp*5-(hz/H0)   # il punto più alto (torretta) sta verso il retro
    if best is None or score>best[0]: best=(score,rot,X,Z,y)
_,rot,X,Z,y=best
ymin=y.min(); h=y.max()-ymin
sx=1.0
Y=(y-ymin-0.04*h)/( (y.max()-ymin) )   # altezza relativa
scale_y=min(W0/ (np.ptp(X)+1e-9), 1.0)
# altezza: proporzione del modello rispetto al lato lungo
ext_long=max(np.ptp(V[:,0]),np.ptp(V[:,2]))
Yc=(y-ymin-0.04*h)*(W0/ext_long)
N=np.stack([X,Yc,Z],1)
keep=N[F][:,:,1].max(1)>0.0
F=F[keep]; N[:,1]=np.maximum(N[:,1],0)
# atlante: sinistra illustrazione (1024x683 → 1024x1024 riquadro), destra parete
art=Image.open('/home/claude/meshy_ws/ref/palazzo_a.png').convert('RGB').resize((1024,1024))
wall=Image.new('RGB',(1024,1024),(222,208,180)); d=ImageDraw.Draw(wall)
rng=np.random.default_rng(1)
for i in range(4000):
    xx,yy=rng.integers(0,1024,2); c=int(rng.integers(-14,14)); d.point((xx,yy),fill=(222+c,208+c,180+c))
d.rectangle((0,420,1024,470),fill=(150,48,38))
for xx in range(20,1024,70):
    d.rectangle((xx,180,xx+26,260),fill=(70,55,45)); d.rectangle((xx,560,xx+26,640),fill=(70,55,45))
wall=wall.filter(ImageFilter.GaussianBlur(0.8))
atlas=Image.new('RGB',(2048,1024)); atlas.paste(art,(0,0)); atlas.paste(wall,(1024,0))
tm=trimesh.Trimesh(N,F,process=False); fn=tm.face_normals
# corrispondenza a riquadri fra modello (frazioni del rettangolo 3x2) e illustrazione (frazioni dell'immagine)
# (geo x0,x1,z0,z1) -> (art x0,x1,y0,y1), altezza minima relativa
REG=[
 ((0.44,0.56,0.36,0.52),(0.44,0.56,0.04,0.14),0.70),  # torretta
 ((0.36,0.66,0.27,0.56),(0.355,0.645,0.06,0.46),0.35), # tetto centrale blu
 ((0.08,0.25,0.48,0.82),(0.06,0.235,0.31,0.56),0.30),  # padiglione sinistro
 ((0.75,0.93,0.48,0.82),(0.765,0.94,0.31,0.56),0.30),  # padiglione destro
 ((0.40,0.62,0.55,0.93),(0.395,0.60,0.47,0.80),0.20),  # ingresso rosso
 ((0.15,0.90,0.24,0.45),(0.10,0.90,0.11,0.30),0.18),   # galleria di fondo
 ((0.15,0.36,0.24,0.62),(0.20,0.33,0.30,0.50),0.18),   # galleria sinistra
 ((0.64,0.88,0.24,0.62),(0.66,0.79,0.30,0.50),0.18),   # galleria destra
 ((0.20,0.40,0.40,0.52),(0.24,0.37,0.31,0.37),0.05),   # siepi
 ((0.60,0.80,0.40,0.52),(0.62,0.76,0.31,0.37),0.05),
 ((0.20,0.40,0.60,0.75),(0.24,0.37,0.58,0.70),0.05),
 ((0.60,0.80,0.60,0.75),(0.62,0.76,0.58,0.70),0.05),
]
HMAX=N[:,1].max()
def art_uv(fx,fz,hrel):
    for g,a,hmin in REG:
        if hrel>=hmin and g[0]<=fx<=g[1] and g[2]<=fz<=g[3]:
            return (a[0]+(fx-g[0])/(g[1]-g[0])*(a[1]-a[0]), a[2]+(fz-g[2])/(g[3]-g[2])*(a[3]-a[2]))
    return None
Vout=[];UV=[];Fout=[]
for i,f in enumerate(F):
    cen=N[f].mean(0); fx=cen[0]/W0; fz=cen[2]/H0; hrel=cen[1]/HMAX
    up=fn[i][1]>0.45
    reg=None
    if up:
        reg=None
        for g,a,hmin in REG:
            if hrel>=hmin and g[0]<=fx<=g[1] and g[2]<=fz<=g[3]:
                reg=(g,a); break
    for j in f:
        p=N[j]
        if up and reg is not None:
            g,a=reg
            px=min(max((p[0]/W0-g[0])/(g[1]-g[0]),0),1); pz=min(max((p[2]/H0-g[2])/(g[3]-g[2]),0),1)
            u=(a[0]+px*(a[1]-a[0]))*0.5; v=a[2]+pz*(a[3]-a[2])
        elif up and hrel<0.12:
            # selciato: un angolo dell'illustrazione ripetuto
            u=(0.005+((p[0]*0.6)%0.07))*0.5; v=0.80+((p[2]*0.6)%0.17)
        elif up:
            u=(p[0]/W0)*0.5; v=p[2]/H0
        else:
            horiz=p[0] if abs(fn[i][0])<abs(fn[i][2]) else p[2]
            u=0.5+(horiz/W0*0.5)%0.5; v=min(0.99,max(0.01,1.0-p[1]/1.3))
        Vout.append(p); UV.append((u,1.0-v))
    Fout.append([3*i,3*i+1,3*i+2])
Vout=np.array(Vout)-np.array([W0/2,0,H0/2]); Fout=np.array(Fout); UV=np.array(UV)
t2=trimesh.Trimesh(Vout,Fout,process=False)
write_glb('/home/claude/meshy_ws/fit/palazzo.glb',Vout,Fout,UV,t2.vertex_normals,atlas)
print('palazzo rot',rot,'facce',len(Fout),'altezza %.2f'%Vout[:,1].max())
