import sys, os, json, io
import numpy as np, trimesh, pymeshlab
from PIL import Image
import os
SRC=os.environ.get('SRC','/home/claude/meshy_ws/m3d'); OUT='/home/claude/meshy_ws/proc'
TARGET=int(os.environ.get('TARGET','12000'))
def proc(nm):
    sc=trimesh.load(f'{SRC}/{nm}.glb')
    g=list(sc.geometry.values())[0]
    tex=g.visual.material.baseColorTexture
    d=f'{OUT}/{nm}'; os.makedirs(d,exist_ok=True)
    # OBJ con texture per pymeshlab
    tex.convert('RGB').save(f'{d}/tex.png')
    uv=g.visual.uv
    with open(f'{d}/in.obj','w') as f:
        f.write('mtllib in.mtl\nusemtl m\n')
        np.savetxt(f, g.vertices, fmt='v %.6f %.6f %.6f')
        np.savetxt(f, uv, fmt='vt %.6f %.6f')
        fa=g.faces+1
        np.savetxt(f, np.stack([fa[:,0],fa[:,0],fa[:,1],fa[:,1],fa[:,2],fa[:,2]],1), fmt='f %d/%d %d/%d %d/%d')
    open(f'{d}/in.mtl','w').write('newmtl m\nmap_Kd tex.png\n')
    ms=pymeshlab.MeshSet(); ms.load_new_mesh(f'{d}/in.obj')
    ms.meshing_remove_duplicate_vertices()
    ms.meshing_decimation_quadric_edge_collapse_with_texture(targetfacenum=TARGET, qualitythr=0.5, preserveboundary=True, optimalplacement=True)
    ms.save_current_mesh(f'{d}/out.obj', save_wedge_texcoord=True)
    m=trimesh.load(f'{d}/out.obj', process=False)
    if isinstance(m, trimesh.Scene): m=list(m.geometry.values())[0]
    img=tex.convert('RGB').resize((1024,1024), Image.LANCZOS)
    write_glb(f'{OUT}/{nm}.glb', m.vertices, m.faces, m.visual.uv, m.vertex_normals, img)
    print(nm, g.faces.shape[0], '->', m.faces.shape[0], os.path.getsize(f'{OUT}/{nm}.glb')//1024, 'KB', flush=True)


def write_glb(path, V, F, UV, N, img, q=85):
    import pygltflib, struct
    V=np.asarray(V,np.float32); N=np.asarray(N,np.float32); UV=np.asarray(UV,np.float32).copy()
    UV[:,1]=1.0-UV[:,1]
    I=np.asarray(F,np.uint32).reshape(-1)
    b=io.BytesIO(); img.save(b,'JPEG',quality=q); jb=b.getvalue()
    parts=[V.tobytes(),N.tobytes(),UV.tobytes(),I.tobytes(),jb]
    blob=b''; offs=[]
    for p in parts:
        while len(blob)%4: blob+=b'\0'
        offs.append(len(blob)); blob+=p
    G=pygltflib
    g=G.GLTF2(asset=G.Asset(version='2.0',generator='principi'),scene=0,scenes=[G.Scene(nodes=[0])],nodes=[G.Node(mesh=0)],
      buffers=[G.Buffer(byteLength=len(blob))],
      bufferViews=[G.BufferView(buffer=0,byteOffset=offs[0],byteLength=len(parts[0]),target=34962),
                   G.BufferView(buffer=0,byteOffset=offs[1],byteLength=len(parts[1]),target=34962),
                   G.BufferView(buffer=0,byteOffset=offs[2],byteLength=len(parts[2]),target=34962),
                   G.BufferView(buffer=0,byteOffset=offs[3],byteLength=len(parts[3]),target=34963),
                   G.BufferView(buffer=0,byteOffset=offs[4],byteLength=len(parts[4]))],
      accessors=[G.Accessor(bufferView=0,componentType=5126,count=len(V),type='VEC3',min=V.min(0).tolist(),max=V.max(0).tolist()),
                 G.Accessor(bufferView=1,componentType=5126,count=len(N),type='VEC3'),
                 G.Accessor(bufferView=2,componentType=5126,count=len(UV),type='VEC2'),
                 G.Accessor(bufferView=3,componentType=5125,count=len(I),type='SCALAR')],
      images=[G.Image(bufferView=4,mimeType='image/jpeg')],textures=[G.Texture(source=0)],
      materials=[G.Material(pbrMetallicRoughness=G.PbrMetallicRoughness(baseColorTexture=G.TextureInfo(index=0),metallicFactor=0.0,roughnessFactor=0.85))],
      meshes=[G.Mesh(primitives=[G.Primitive(attributes=G.Attributes(POSITION=0,NORMAL=1,TEXCOORD_0=2),indices=3,material=0)])])
    g.set_binary_blob(blob)
    g.save_binary(path)

if __name__=='__main__':
    for nm in sys.argv[1:]:
        proc(nm)
