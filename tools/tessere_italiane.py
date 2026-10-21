import cv2, numpy as np
SH={"universita":["##.","###",".##"],"laboratorio":["##.","###","#.#"],"bottega":["###","###","..#"],"biblioteca":[".#.","###","#.."],
"opera":["###","#..","#.."],"studio":["###","#.#"],"ospedale":["..#","###","#.."],"teatro":[".###","##.."],"torre":["#.","##"],"cappella":["#","#","#"]}
POS={"universita":(798,795),"laboratorio":(1168,997),"bottega":(1517,778),"opera":(656,1777),"ospedale":(944,1840),"studio":(1465,1670),"teatro":(1141,2041),"biblioteca":(1830,1708),"torre":(923,2586),"cappella":(1310,2643)}
im=cv2.imread('mappa-6.jpg'); hsv=cv2.cvtColor(im,cv2.COLOR_BGR2HSV)
par=((hsv[:,:,0]>15)&(hsv[:,:,0]<35)&(hsv[:,:,1]>60)&(hsv[:,:,2]>150)).astype(np.uint8)
obj=(1-par); obj[:, :500]=0; obj[:600,:]=0; obj[3150:,:]=0
obj=cv2.morphologyEx(obj,cv2.MORPH_OPEN,np.ones((9,9),np.uint8)); obj=cv2.morphologyEx(obj,cv2.MORPH_CLOSE,np.ones((15,15),np.uint8))
n,lab,st,cen=cv2.connectedComponentsWithStats(obj)
def grid(cells):
    g=np.zeros((max(len(cells),1),max(len(r) for r in cells)),bool)
    for y,r in enumerate(cells):
        for x,c in enumerate(r): g[y,x]=c=='#'
    return g
def variants(img,mask):
    for f in (False,True):
        for r in range(4):
            a=img[:, ::-1] if f else img; m=mask[:, ::-1] if f else mask
            a=np.rot90(a,r); m=np.rot90(m,r)
            yield f,r,np.ascontiguousarray(a),np.ascontiguousarray(m)
CELL=128
for nm,(x,y) in POS.items():
    i=min([k for k in range(1,n) if st[k][4]>40000],key=lambda k:(st[k][0]-x)**2+(st[k][1]-y)**2)
    sx,sy,w,h,_=st[i]
    m=(lab[sy:sy+h,sx:sx+w]==i).astype(np.uint8)*255; c=im[sy:sy+h,sx:sx+w]
    target=grid(SH[nm]); best=None
    for f,r,a,mm in variants(c,m):
        th,tw=target.shape
        mr=cv2.resize(mm,(tw*10,th*10),interpolation=cv2.INTER_AREA)>127
        tg=np.kron(target,np.ones((10,10),bool))
        sc=(mr==tg).mean()
        if best is None or sc>best[0]: best=(sc,f,r,a,mm)
    sc,f,r,a,mm=best
    th,tw=target.shape
    a=cv2.resize(a,(tw*CELL,th*CELL),interpolation=cv2.INTER_AREA); mm=cv2.resize(mm,(tw*CELL,th*CELL),interpolation=cv2.INTER_AREA)
    # alfa: la sagoma esatta, con il bordo del pezzo
    alpha=np.kron(target.astype(np.uint8)*255,np.ones((CELL,CELL),np.uint8))
    alpha=cv2.GaussianBlur(alpha,(3,3),0)
    out=np.dstack([a,alpha]); cv2.imwrite('tiles/%s.png'%nm,out)
    print(nm,'accordo %.2f'%sc,'flip',f,'rot',r)
