import numpy as np
S=4.0  # da coordinate 0.25 a piena risoluzione
A={0:(70,62),1:(180,42),8:(782,42),9:(868,42),17:(1526,52),18:(1560,170),24:(1560,690),25:(1552,712),26:(1468,758),33:(868,758),34:(782,758),41:(180,758),42:(105,738),43:(45,670),49:(42,172)}
def interp(a,b):
    pa=np.array(A[a]); pb=np.array(A[b]); return {i:tuple(pa+(pb-pa)*(i-a)/(b-a)) for i in range(a,b+1)}
P={}
for a,b in [(1,8),(9,17),(18,24),(26,33),(34,41),(43,49)]: P.update(interp(a,b))
for k in (0,25,42): P[k]=A[k]
pos={k:(v[0]*S,v[1]*S) for k,v in P.items()}
