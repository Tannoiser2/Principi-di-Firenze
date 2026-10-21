import cv2, numpy as np, json
B=cv2.imread('assets/board/tabellone.jpg'); B=cv2.resize(B,None,fx=0.4,fy=0.4,interpolation=cv2.INTER_AREA); G=cv2.cvtColor(B,cv2.COLOR_BGR2GRAY).astype(np.float32)
H,W=G.shape
res={}
import sys
names=sys.argv[1:] or ['universita','laboratorio','bottega','biblioteca','opera','studio','ospedale','teatro','torre','cappella','bosco','lago','parco']
for nm in names:
    t=cv2.imread(f'assets/tiles/{nm}.png',cv2.IMREAD_UNCHANGED)
    best=None
    for flip in (False,True):
        for rot in range(4):
            tt=t.copy()
            if flip: tt=cv2.flip(tt,1)
            for _ in range(rot): tt=cv2.rotate(tt,cv2.ROTATE_90_CLOCKWISE)
            for sc in np.arange(0.95,1.36,0.05):
                ts=cv2.resize(tt,None,fx=sc*0.4,fy=sc*0.4,interpolation=cv2.INTER_AREA)
                g=cv2.cvtColor(ts[:,:,:3],cv2.COLOR_BGR2GRAY).astype(np.float32)
                m=(ts[:,:,3]>128).astype(np.float32)
                r=cv2.matchTemplate(G,g,cv2.TM_CCORR_NORMED,mask=m)
                r=np.nan_to_num(r,nan=0,posinf=0,neginf=0)
                _,mx,_,loc=cv2.minMaxLoc(r)
                if best is None or mx>best[0]:
                    best=(mx,flip,rot,float(sc),loc,ts.shape[1],ts.shape[0])
    mx,flip,rot,sc,loc,w,h=best
    cx=(loc[0]+w/2)/W; cy=(loc[1]+h/2)/H
    res[nm]={'score':round(mx,4),'flip':flip,'rot':rot,'scale':round(sc,3),'cx':round(cx,4),'cy':round(cy,4),'w':w,'h':h}
    print(nm,res[nm],flush=True)
json.dump(res,open('/home/claude/scratch/match.json','w'),indent=1)
