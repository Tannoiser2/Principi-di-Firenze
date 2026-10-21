import cv2, numpy as np, json
COL={2:'giallo',4:'verde',6:'blu',8:'nero',10:'rosso'}
out={}
for p,col in COL.items():
    im=cv2.imread('plance-%02d.jpg'%p)
    g=cv2.cvtColor(im,cv2.COLOR_BGR2GRAY)
    ys,xs=np.where(g<215); y0,y1=int(np.percentile(ys,0.5)),int(np.percentile(ys,99.5)); x0,x1=int(np.percentile(xs,0.5)),int(np.percentile(xs,99.5))
    im=im[y0:y1,0:x1]  # il bordo sinistro del foglio taglia la griglia: si tiene da x=0
    best=None
    for k in range(4):
        r=np.rot90(im,k).copy(); hsv=cv2.cvtColor(r,cv2.COLOR_BGR2HSV)
        gr=((hsv[:,:,0]>25)&(hsv[:,:,0]<60)&(hsv[:,:,1]>60)).astype(np.uint8)
        top=gr[:150].mean()  # griglia lungo il bordo in alto
        if best is None or top>best[0]: best=(top,k,r,gr)
    _,k,r,gr=best
    gr=cv2.morphologyEx(gr,cv2.MORPH_OPEN,np.ones((15,15),np.uint8))
    # griglia: righe in alto con molta erba
    rows=np.where(gr.mean(1)>0.3)[0]; rows=rows[rows<1400]
    gy0,gy1=0,rows.max()
    cols=np.where(gr[gy0:gy1].mean(0)>0.5)[0]; gx0,gx1=cols.min(),cols.max()
    cw=(gx1-gx0)/10.0; chh=(gy1-gy0)/5.0
    # palazzo: celle con poca erba
    pal=[]
    for cy in range(5):
        for cx in range(10):
            c=gr[int(gy0+(cy+.25)*chh):int(gy0+(cy+.75)*chh), int(gx0+(cx+.25)*cw):int(gx0+(cx+.75)*cw)]
            if c.mean()<0.3: pal.append([cx,cy])
    cv2.imwrite('plb_%s.jpg'%col,r,[cv2.IMWRITE_JPEG_QUALITY,92])
    out[col]={'W':r.shape[1],'H':r.shape[0],'x0':int(gx0),'y0':int(gy0),'cw':cw,'ch':chh,'pal':pal,'rot':k}
    print(col,k,r.shape[1],r.shape[0],'griglia',gx0,gx1,gy0,gy1,'cella %.1f %.1f'%(cw,chh),'palazzo',pal)
json.dump(out,open('grid_b_it.json','w'),indent=1)
