import cv2, numpy as np
def load(i,rot):
    im=cv2.imread('mappa-%d.jpg'%i)
    g=cv2.cvtColor(im,cv2.COLOR_BGR2GRAY)
    # bordo inferiore della scansione (zona grigia del coperchio)
    rows=(g[:, 300:2200]>185).mean(1)
    cut=next(y for y in range(2600,g.shape[0]) if rows[y]>0.6)-15
    mask=np.zeros(g.shape,np.uint8); mask[:cut,:]=255
    # bordo destro: colonne grigie
    cols=(g[:cut, :]>185).mean(0)
    if rot:
        im=cv2.rotate(im,cv2.ROTATE_180); mask=cv2.rotate(mask,cv2.ROTATE_180)
    return im,mask
sift=cv2.SIFT_create(6000)
def affine(dst,src,dmask=None,smask=None,s=0.5):
    a=cv2.resize(dst,None,fx=s,fy=s); b=cv2.resize(src,None,fx=s,fy=s)
    ma=None if dmask is None else cv2.resize(dmask,None,fx=s,fy=s)
    mb=None if smask is None else cv2.resize(smask,None,fx=s,fy=s)
    ka,da=sift.detectAndCompute(cv2.cvtColor(a,cv2.COLOR_BGR2GRAY),ma)
    kb,db=sift.detectAndCompute(cv2.cvtColor(b,cv2.COLOR_BGR2GRAY),mb)
    m=cv2.BFMatcher().knnMatch(db,da,k=2); good=[x for x,y in m if x.distance<0.7*y.distance]
    pb=np.float32([kb[g.queryIdx].pt for g in good])/s; pa=np.float32([ka[g.trainIdx].pt for g in good])/s
    H,mk=cv2.estimateAffinePartial2D(pb,pa,ransacReprojThreshold=6)
    return H,int(mk.sum())
P2,M2=load(2,False); P3,M3=load(3,False); P4,M4=load(4,True); P5,M5=load(5,True)
H42,n1=affine(P2,P4); print('p4->p2',n1,H42.round(3).tolist())
H53,n2=affine(P3,P5); print('p5->p3',n2,H53.round(3).tolist())
# p3 -> p4rot con le strisce del percorso (traslazione)
H34=np.float32([[1,0,2563],[0,1,276]])
def comp(A,B):  # A∘B
    A3=np.vstack([A,[0,0,1]]); B3=np.vstack([B,[0,0,1]]); return (A3@B3)[:2]
H32=comp(H42,H34); H52=comp(H32,H53)
W,H=6300,3500; off=np.float32([[1,0,0],[0,1,300]])
canvas=np.zeros((H,W,3),np.uint8); filled=np.zeros((H,W),np.uint8)
for im,mk,T in [(P5,M5,H52),(P3,M3,H32),(P4,M4,H42),(P2,M2,np.float32([[1,0,0],[0,1,0]]))]:
    T2=comp(np.vstack([off,[0,0,1]])[:2],T)
    w=cv2.warpAffine(im,T2,(W,H)); wm=cv2.warpAffine(mk,T2,(W,H),flags=cv2.INTER_NEAREST)
    wm=cv2.erode(wm,np.ones((15,15),np.uint8))
    canvas[wm>0]=w[wm>0]; filled|=wm
ys,xs=np.where(filled>0); print('area',xs.min(),xs.max(),ys.min(),ys.max())
cv2.imwrite('board_raw.jpg',canvas,[cv2.IMWRITE_JPEG_QUALITY,90])
small=cv2.resize(canvas,None,fx=0.25,fy=0.25); cv2.imwrite('/home/claude/scratch/board_raw.jpg',small)
# riempimento della piega centrale e ritaglio
ys,xs=np.where(filled>0)
x0,x1,y0,y1=xs.min(),xs.max(),ys.min(),ys.max()
# riquadro interno con contenuto in tutte le colonne
colfrac=(filled>0).mean(0); rowfrac=(filled>0).mean(1)
good_rows=np.where((filled[:, 200:6000]>0).mean(1)>0.9)[0]
yt,yb=good_rows.min(),good_rows.max()
good_cols=np.where((filled[yt:yb]>0).mean(0)>0.5)[0]
xl,xr=good_cols.min(),good_cols.max()
crop=canvas[yt:yb,xl:xr].copy(); fm=(filled[yt:yb,xl:xr]==0).astype(np.uint8)*255
crop=cv2.inpaint(crop,cv2.dilate(fm,np.ones((5,5),np.uint8)),9,cv2.INPAINT_TELEA)
print('ritaglio',xl,xr,yt,yb, crop.shape)
cv2.imwrite('tabellone_it.jpg',crop,[cv2.IMWRITE_JPEG_QUALITY,92])
cv2.imwrite('/home/claude/scratch/tab_it.jpg',cv2.resize(crop,None,fx=0.25,fy=0.25))
