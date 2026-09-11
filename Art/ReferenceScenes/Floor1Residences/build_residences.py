"""Five original Floor-1 residential exteriors, metres / Z-up.

Blender --background --python build_residences.py
Authored geometry and periodic PBR textures; no downloaded art dependency.
UV0 is a directional metric tiling map (2 m repeats). UV1 is a unique packed
secondary unwrap, not a baked lightmap. Closed doors, unfurnished shells.
"""
from __future__ import annotations
import hashlib
import json
import math
import random
from pathlib import Path
import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / 'game/assets/floor1/residences'
TEX = OUT / 'textures'
R = random.Random(411)
N = 2048
MATS = {}
PALETTE = {'stone':'C8BCA1', 'trim':'E3D5B7', 'plaster':'EEE3CB',
           'rose':'DBC1B2', 'sage':'CBD0B8', 'bluewall':'CCD7D0',
           'oak':'78604A', 'darkwood':'534B3E', 'door':'93714D',
           'shutter':'719188', 'blueshutter':'637F89', 'roof':'B37B68',
           'slate':'71898C', 'iron':'465454', 'brass':'C1A572',
           'glass':'536C6E', 'warmglass':'A69F77', 'shadow':'292C2A',
           'leaf':'708653', 'flower':'DAB5B4', 'soil':'514A39'}


def linear(h):
    a = [int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(x/12.92 if x < .04045 else ((x+.055)/1.055)**2.4 for x in a)+(1,)


def periodic_noise(n, cells, seed):
    rng = np.random.default_rng(seed)
    grid = rng.uniform(-1,1,(cells,cells)).astype(np.float32)
    q = np.arange(n,dtype=np.float32)*cells/n
    lo = np.floor(q).astype(int); f=q-lo; f=f*f*(3-2*f)
    a = grid[lo[:,None]%cells,lo[None,:]%cells]
    b = grid[lo[:,None]%cells,(lo[None,:]+1)%cells]
    c = grid[(lo[:,None]+1)%cells,lo[None,:]%cells]
    d = grid[(lo[:,None]+1)%cells,(lo[None,:]+1)%cells]
    return ((a*(1-f[None,:])+b*f[None,:])*(1-f[:,None])+(c*(1-f[None,:])+d*f[None,:])*f[:,None]).astype(np.float32)


def image_file(name, rgb, noncolor=False):
    im=bpy.data.images.new(name,width=N,height=N,alpha=True)
    im.colorspace_settings.name='Non-Color' if noncolor else 'sRGB'
    data=np.ones((N,N,4),dtype=np.float32);data[:,:,:3]=np.clip(rgb,0,1)
    # Blender generated image pixels are linear for colour images.
    if not noncolor:
        v=data[:,:,:3];data[:,:,:3]=np.where(v<=.04045,v/12.92,((v+.055)/1.055)**2.4)
    im.pixels.foreach_set(data.ravel());im.filepath_raw=str(TEX/(name+'.png'))
    im.file_format='PNG';im.save();im.pack()
    return im


def textures():
    TEX.mkdir(parents=True,exist_ok=True)
    y,x=np.mgrid[0:N,0:N].astype(np.float32)/N
    low=periodic_noise(N,8,431);mid=periodic_noise(N,47,432)
    fine=periodic_noise(N,257,433)
    maps={}
    for kind in ('plaster','limestone','oak','clay'):
        if kind=='plaster':
            h=low*.018+mid*.018+fine*.015
            value=.96+low*.012+mid*.008+fine*.004; rough=.88+h*.07; strength=.45
        elif kind=='limestone':
            h=low*.035+mid*.032+fine*.018-np.maximum(.15-mid,0)**2*.02
            value=.94+low*.025+mid*.014+fine*.007;rough=.79+h*.15;strength=.65
        elif kind=='oak':
            warp=.006*np.sin(y*math.tau*2)+low*.003
            grain=np.sin((x+warp)*math.tau*56)
            pore=np.maximum(np.sin((x+warp)*math.tau*169)-.65,0)
            h=.010*grain-.018*pore+mid*.005
            value=.88+grain*.028-pore*.035+low*.015;rough=.69+grain*.025;strength=.38
        else:
            h=.023*mid+.015*fine+low*.01
            value=.93+low*.018+mid*.012+fine*.006;rough=.71+mid*.025;strength=.5
        albedo=np.repeat(value[:,:,None],3,axis=2)
        # Neutral albedo is multiplied by per-corner linear palette in both engines.
        dx=(np.roll(h,-1,1)-np.roll(h,1,1))*strength*13
        dy=(np.roll(h,-1,0)-np.roll(h,1,0))*strength*13
        normal=np.stack((-dx,-dy,np.ones_like(dx)),axis=2)
        normal/=np.linalg.norm(normal,axis=2)[:,:,None];normal=normal*.5+.5
        orm=np.stack((np.ones_like(h),rough,np.zeros_like(h)),axis=2)
        maps[kind]=(image_file(kind+'_albedo',albedo),image_file(kind+'_normal',normal,True),image_file(kind+'_orm',orm,True))
    return maps


def material(role):
    kind={'stone':'limestone','trim':'limestone','plaster':'plaster','rose':'plaster','sage':'plaster','bluewall':'plaster',
          'oak':'oak','darkwood':'oak','door':'oak','shutter':'oak','blueshutter':'oak','roof':'clay','slate':'clay',
          'iron':'metal','brass':'metal','glass':'glass','warmglass':'glass'}.get(role,'plain')
    if kind in MATS:return MATS[kind]
    mat=bpy.data.materials.new('Residence_'+kind);mat.use_nodes=True
    nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF')
    col=nt.nodes.new('ShaderNodeVertexColor');col.layer_name='Col'
    nt.links.new(col.outputs['Color'],bs.inputs['Base Color'])
    bs.inputs['Roughness'].default_value=.56
    if kind=='metal':bs.inputs['Metallic'].default_value=.72;bs.inputs['Roughness'].default_value=.34
    if kind=='glass':bs.inputs['Roughness'].default_value=.24
    if kind in MAPS:
        a,n,o=MAPS[kind]
        tex=nt.nodes.new('ShaderNodeTexImage');tex.image=a
        mix=nt.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1
        nt.links.new(tex.outputs['Color'],mix.inputs[1]);nt.links.new(col.outputs['Color'],mix.inputs[2]);nt.links.new(mix.outputs[0],bs.inputs['Base Color'])
        normal=nt.nodes.new('ShaderNodeTexImage');normal.image=n
        bump=nt.nodes.new('ShaderNodeNormalMap');bump.inputs['Strength'].default_value=.7
        nt.links.new(normal.outputs['Color'],bump.inputs['Color']);nt.links.new(bump.outputs['Normal'],bs.inputs['Normal'])
        packed=nt.nodes.new('ShaderNodeTexImage');packed.image=o
        sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(packed.outputs['Color'],sep.inputs[0])
        nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
    MATS[kind]=mat
    return mat


class Geo:
    def __init__(self):self.v=[];self.f=[];self.roles=[];self.uv=[];self.colors=[]
    def mesh(self,verts,faces,role,local=None,shade=1):
        offset=len(self.v);self.v.extend(tuple(v) for v in verts)
        colour=linear(PALETTE.get(role,role));colour=tuple(min(1,c*shade) for c in colour[:3])+(1,)
        for face in faces:
            self.f.append(tuple(offset+i for i in face));self.roles.append(role);self.colors.append(colour)
            coords=[Vector((local or verts)[i]) for i in face]
            normal=(coords[1]-coords[0]).cross(coords[2]-coords[0])
            axis=max(range(3),key=lambda i:abs(normal[i]));axes=[i for i in range(3) if i!=axis]
            self.uv.append([(v[axes[0]]*.5,v[axes[1]]*.5) for v in coords])
    def box(self,p,s,role='stone',rot=None,shade=1):
        vs=[Vector((x*s[0]/2,y*s[1]/2,z*s[2]/2)) for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        self.mesh([Vector(p)+(rot@v if rot else v) for v in vs],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],role,vs,shade)
    def beam(self,a,b,w,role='oak',d=None):
        a,b=Vector(a),Vector(b);v=b-a
        self.box((a+b)/2,(w,d or w,v.length),role,v.to_track_quat('Z','Y').to_matrix())
    def add(self,g,p=(0,0,0),yaw=0):
        base=len(self.v);rot=Matrix.Rotation(math.radians(yaw),3,'Z')
        self.v.extend(tuple(rot@Vector(v)+Vector(p)) for v in g.v)
        self.f.extend(tuple(base+i for i in f) for f in g.f)
        self.roles.extend(g.roles);self.uv.extend(g.uv);self.colors.extend(g.colors)
    def rings(self,p,profile,role,n=16):
        vs=[(p[0]+r*math.cos(i*math.tau/n),p[1]+r*math.sin(i*math.tau/n),p[2]+z) for r,z in profile for i in range(n)]
        fs=[tuple(range(n-1,-1,-1)),tuple((len(profile)-1)*n+i for i in range(n))]
        for j in range(len(profile)-1):
            for i in range(n):
                a=j*n+i;b=j*n+(i+1)%n;fs.append((a,b,b+n,a+n))
        self.mesh(vs,fs,role)
    def arch(self,x,y,spring,r,t,depth,role='trim',segments=16):
        for i in range(segments):
            a=math.pi*i/segments+.003;b=math.pi*(i+1)/segments-.003
            vs=[(x+rad*math.cos(th),y+dy,spring+rad*math.sin(th)) for dy in (-depth/2,depth/2) for rad,th in [(r,a),(r,b),(r+t,b),(r+t,a)]]
            self.mesh(vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],role)
    def disk(self,x,y,z,r,role='brass'):
        vs=[(x+r*math.cos(t*math.tau/16),y,z+r*math.sin(t*math.tau/16)) for t in range(16)]
        self.mesh(vs,[tuple(range(16))],role)
    def object(self,name,col):
        me=bpy.data.meshes.new(name);me.from_pydata(self.v,[],self.f);me.update()
        ob=bpy.data.objects.new(name,me);col.objects.link(ob)
        kinds=[]
        for role in self.roles:
            mat=material(role)
            if mat not in kinds:kinds.append(mat);me.materials.append(mat)
        uv=me.uv_layers.new(name='UV0_Metric_2m');colors=me.color_attributes.new(name='Col',type='FLOAT_COLOR',domain='CORNER')
        for poly,role,coords,color in zip(me.polygons,self.roles,self.uv,self.colors):
            poly.material_index=kinds.index(material(role))
            for li,co in zip(poly.loop_indices,coords):uv.data[li].uv=co;colors.data[li].color=color
        me.color_attributes.active_color=colors
        bpy.context.view_layer.objects.active=ob;ob.select_set(True)
        bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
        bevel=ob.modifiers.new('Crafted 8mm edge highlights','BEVEL');bevel.width=.008;bevel.segments=1;bevel.limit_method='ANGLE';bevel.angle_limit=.7
        bpy.ops.object.modifier_apply(modifier=bevel.name)
        # Independent unique unwrap: existing metric map is not overwritten.
        me.uv_layers.new(name='UV1_Unique_Packed');me.uv_layers.active_index=1
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.004,area_weight=.6,correct_aspect=True,scale_to_bounds=True)
        bpy.ops.object.mode_set(mode='OBJECT');me.uv_layers.active_index=0;me.uv_layers[0].active_render=True
        bm=bmesh.new();bm.from_mesh(me);bmesh.ops.triangulate(bm,faces=list(bm.faces))
        bad=[f for f in bm.faces if f.calc_area()<1e-8]
        if bad:bmesh.ops.delete(bm,geom=bad,context='FACES_ONLY')
        bm.to_mesh(me);bm.free();me.update()
        ob['unit']='metre';ob['source']='original authored residential exterior';ob['uv0']='2m directional tile; intentional material reuse';ob['uv1']='unique packed secondary UV, no light bake'
        return ob


def subtract(rect,holes):
    pieces=[rect]
    for a,b,c,d in holes:
        result=[]
        for l,r,bot,top in pieces:
            u,v=max(l,a),min(r,b);s,t=max(bot,c),min(top,d)
            if u>=v or s>=t:result.append((l,r,bot,top));continue
            if l<u:result.append((l,u,bot,top))
            if v<r:result.append((v,r,bot,top))
            if bot<s:result.append((u,v,bot,s))
            if t<top:result.append((u,v,t,top))
        pieces=result
    return pieces


def wall(g,w,h,holes,plaster):
    for bot,top,role in [(.35,min(3.2,h),'stone'),(3.2,h,plaster)]:
        if top<=bot:continue
        for l,r,b,t in subtract((-w/2,w/2,bot,top),holes):
            g.box(((l+r)/2,.13,(b+t)/2),(r-l,.26,t-b),role)
    # Individual cut limestone courses only at the ground storey.
    rowh=.39;bw=.79
    for row in range(7):
        z0=.38+row*rowh;z1=z0+rowh-.018
        for i in range(math.ceil(w/bw)+1):
            x0=max(-w/2,-w/2+i*bw-(bw*.5 if row%2 else 0));x1=min(w/2,-w/2+(i+1)*bw-(bw*.5 if row%2 else 0)-.018)
            if x1-x0<.04:continue
            for l,r,b,t in subtract((x0,x1,z0,z1),holes):
                if min(r-l,t-b)>.025:g.box(((l+r)/2,-.025,(b+t)/2),(r-l,.09,t-b),'stone',shade=R.uniform(.94,1.04))
    for z in (.34,3.2,h-.22,h-.05):
        g.box((0,-.04,z),(w+.12,.35,.14 if z< h-.3 else .12),'trim')
    for side in (-1,1):
        for z in np.arange(.57,h-.3,.48):g.box((side*(w/2-.13),-.055,z),(.30 if int(z*2)%2 else .44,.32,.445),'trim')


def opening(g,x,z,w,h,door=False,shutter='shutter',arched=True):
    y=-.01;r=w/2;spring=z+h-r
    # Dark inner reveal and inset physical glazing/door; no flat black decal.
    g.box((x,.235,z+h/2),(w,.055,h),'shadow')
    if arched:
        vs=[(x-r,.18,z),(x+r,.18,z)]+[(x+r*math.cos(i*math.pi/20),.18,spring+r*math.sin(i*math.pi/20)) for i in range(21)]
        g.mesh(vs,[tuple(reversed(range(len(vs))))],'door' if door else 'glass')
        g.arch(x,-.065,spring,r,.16,.27,'trim',20)
        g.arch(x,-.115,spring,r+.17,.047,.32,'stone',24)
    else:
        g.box((x,.17,z+h/2),(w,.08,h),'door' if door else 'glass')
        g.box((x,-.07,z+h+.07),(w+.36,.3,.14),'trim')
    for side in (-1,1):
        g.box((x+side*(r+.085),-.075,z+(spring-z)/2 if arched else z+h/2),(.17,.30,spring-z if arched else h),'trim')
        g.box((x+side*(r-.028),.08,z+(spring-z)/2 if arched else z+h/2),(.058,.13,spring-z if arched else h),'darkwood')
    for zz,ww,dd,hh in [(z-.08,w+.44,.46,.16),(z-.17,w+.32,.35,.05)]:g.box((x,-.08,zz),(ww,dd,hh),'trim')
    if door:
        for i in range(8):
            xx=-r+(i+.5)*w/8;top=spring+math.sqrt(max(0,r*r-xx*xx)) if arched else z+h
            g.box((x+xx,.09,(z+top)/2),(w/8-.011,.075,top-z),'door',shade=R.uniform(.9,1.08))
        for zz in (z+.36,z+1.5):
            g.box((x,.025,zz),(w*.87,.04,.07),'iron')
            for dx in (-.36,.0,.36):g.disk(x+dx,-.002,zz,.021,'brass')
        g.box((x+r*.55,-.025,z+1.02),(.1,.045,.23),'iron')
        pts=[(x+r*.55+.058*math.cos(i*math.tau/16),-.074,z+1.05+.07*math.sin(i*math.tau/16)) for i in range(17)]
        for a,b in zip(pts,pts[1:]):g.beam(a,b,.014,'brass')
        g.box((x-r-.39,-.17,z+1.45),(.23,.07,.30),'slate')
        g.box((x-r-.39,-.214,z+1.45),(.09,.025,.09),'brass',Matrix.Rotation(math.pi/4,3,'Y'))
    else:
        g.box((x,.06,z+h*.48),(.065,.13,h*.96),'oak')
        for zz in (z+h*.35,z+h*.68):g.box((x,.05,zz),(w,.12,.046),'oak')
        # Fine diamond leadwork within rectangular portion of recessed glazing.
        for k in range(-4,5):
            for sign in (-1,1):
                pts=[]
                for xx in np.linspace(-r+.045,r-.045,45):
                    zz=z+.15+k*.32+sign*xx
                    if z+.04<zz<spring-.035:pts.append((x+xx,.055,zz))
                if len(pts)>1:g.beam(pts[0],pts[-1],.009,'brass')
        if shutter:
            for side in (-1,1):
                center=x+side*(r+.37)
                g.box((center,-.12,z+(h-.14)/2),(.39,.08,h-.14),shutter)
                for dz in (.12,h-.26):g.box((center,-.18,z+dz),(.43,.06,.07),'oak')
                for zz in np.arange(z+.3,z+h-.27,.13):g.box((center,-.178,zz),(.32,.055,.06),shutter,Matrix.Rotation(.13,3,'X'))


def tile(g,origin,u,v,normal,w,length,role):
    # Curved shoulder and clipped beavertail lip; actual overlap and thickness.
    poly=[(-w/2,0),(w/2,0),(w/2,length*.76),(w*.36,length*.96),(0,length),(-w*.36,length*.96),(-w/2,length*.76)]
    o=Vector(origin);u=Vector(u);v=Vector(v);n=Vector(normal)
    verts=[o+u*a+v*b+n*(th+.014*math.sin((a/w+.5)*math.pi)) for th in (0,.035) for a,b in poly]
    count=len(poly);faces=[tuple(range(count-1,-1,-1)),tuple(range(count,count*2))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    local=[(a,b,th) for th in (0,.035) for a,b in poly]
    g.mesh(verts,faces,role,local,R.uniform(.87,1.09))


def roof(g,w,d,eave,rise,role='roof',hip=False):
    half=w/2+.43;end=d/2+.44;length=math.hypot(half,rise)
    inset=min(rise,half,end*.65) if hip else 0
    for side in (-1,1):
        down=Vector((side*half/length,0,-rise/length));normal=Vector((side*rise/length,0,half/length));u=Vector((0,1,0))
        vs=[(0,-end+inset,eave+rise),(side*half,-end,eave),(side*half,end,eave),(0,end-inset,eave+rise)]
        g.mesh(vs,[(0,1,2,3)],role)
        rows=math.ceil(length/.38);cols=math.ceil(2*end/.31);pitch=length/rows;tw=2*end/cols
        for row in range(rows):
            along=row*pitch
            for col in range(cols):
                yy=-end+(col+.5)*tw
                if hip and abs(yy)>end-inset*(1-along/length)-tw*.35:continue
                at=Vector((0,yy,eave+rise))+down*along+normal*(.014+row*.00025)
                tile(g,at,u,down,normal,tw-.006,pitch+.11,role)
        for sy in (-1,1):g.beam((0,sy*(end-inset),eave+rise+.025),(side*half,sy*end,eave+.015),.15,'darkwood')
        g.beam((side*half,-end,eave),(side*half,end,eave),.15,'darkwood')
        g.beam((side*(half-.11),-end,eave-.09),(side*(half-.11),end,eave-.09),.075,'trim')
    # Rounded barrel ridge caps, individually jointed, not a sawtooth finial.
    for yy in np.arange(-end+inset,end-inset,.34):
        verts=[(radius*math.cos(a*math.pi/10),yy+dy,eave+rise+.02+radius*math.sin(a*math.pi/10)) for dy in (0,.33) for radius in (.125,.16) for a in range(11)]
        faces=[]
        for a in range(10):
            faces.extend([(a,a+1,a+23,a+22),(a+11,a+33,a+34,a+12),(a,a+11,a+12,a+1),(a+22,a+23,a+34,a+33)])
        faces.extend([(0,22,33,11),(10,21,43,32)])
        g.mesh(verts,faces,role)
    if hip:
        # True triangular hip slopes, covered with the same physical tile courses.
        for sy in (-1,1):
            apex=Vector((0,sy*(end-inset),eave+rise+.045))
            a=Vector((-half,sy*end,eave+.03));b=Vector((half,sy*end,eave+.03))
            g.mesh([apex,a,b],[(0,1,2)],role)
            slen=math.hypot(inset,rise);down=Vector((0,sy*inset/slen,-rise/slen));normal=Vector((0,sy*rise/slen,inset/slen))
            rows=math.ceil(slen/.38)
            for row in range(1,rows):
                frac=row/rows;span=half*frac;count=max(1,int(2*span/.31))
                for col in range(count):
                    xx=-span+(col+.5)*2*span/count
                    tile(g,apex+down*(slen*frac)+Vector((xx,0,0)),(1,0,0),down,normal,2*span/count-.009,slen/rows+.10,role)


def balcony(g,x,y,z,w,depth=1.05,covered=False):
    g.box((x,y-depth/2,z),(w+.28,depth,.19),'trim')
    for dx in np.arange(-w/2+.15,w/2,.55):
        g.beam((x+dx,y-.05,z-.65),(x+dx,y-depth+.07,z-.11),.10,'oak')
    g.beam((x-w/2,y-depth,z+1.0),(x+w/2,y-depth,z+1.0),.095,'oak')
    g.beam((x-w/2,y-depth,z+.15),(x+w/2,y-depth,z+.15),.07,'oak')
    for xx in np.arange(x-w/2,x+w/2+.01,.22):g.beam((xx,y-depth,z+.18),(xx,y-depth,z+.96),.035,'iron')
    for side in (-1,1):
        for yy in np.arange(y-depth,y,.22):g.beam((x+side*w/2,yy,z+.18),(x+side*w/2,yy,z+.96),.035,'iron')
        g.beam((x+side*w/2,y-depth,z+1),(x+side*w/2,y,z+1),.09,'oak')
    if covered:
        for side in (-1,1):g.beam((x+side*w/2,y-depth,z),(x+side*w/2,y-depth,z+2.55),.14,'oak')
        down=Vector((0,-1,-.16)).normalized();normal=Vector((0,-.16,1)).normalized()
        for row in range(4):
            for xx in np.arange(x-w/2-.15,x+w/2+.2,.30):tile(g,Vector((xx,y+.03,z+2.68))+down*(row*.39),(1,0,0),down,normal,.295,.49,'roof')
        g.beam((x-w/2-.2,y-depth-.18,z+2.43),(x+w/2+.2,y-depth-.18,z+2.43),.12,'oak')


def lantern(g,x,y,z):
    g.box((x,y+.02,z+.20),(.16,.16,.52),'iron')
    g.beam((x,y,z+.39),(x,y-.35,z+.39),.045,'iron')
    g.box((x,y-.33,z),(.19,.19,.31),'warmglass')
    for dx in (-.105,.105):
        for dy in (-.105,.105):g.beam((x+dx,y-.33+dy,z-.19),(x+dx,y-.33+dy,z+.19),.018,'iron')
    g.rings((x,y-.33,z+.16),[(.17,0),(.12,.075),(.035,.17)],'iron',4)
    g.box((x,y-.33,z-.18),(.25,.25,.045),'brass')


def flowerbox(g,x,y,z,w):
    g.box((x,y,z),(w,.37,.27),'oak')
    g.box((x,y-.195,z+.04),(w+.06,.07,.055),'trim')
    for side in (-1,1):g.box((x+side*w*.35,y-.21,z),(.055,.05,.3),'iron')
    for i in range(int(w*8)):
        xx=x+R.uniform(-w*.44,w*.44);yy=y+R.uniform(-.12,.12);zz=z+.21+R.uniform(.02,.22)
        g.beam((xx,yy,z+.13),(xx,yy,zz),.012,'leaf')
        for j in range(4):
            angle=j*math.tau/4+R.random();d=Vector((math.cos(angle)*.085,math.sin(angle)*.085,.035))
            at=Vector((xx,yy,zz));side=Vector((-d.y,d.x,0))*.4
            g.mesh([at,at+d*.5+side,at+d,at+d*.5-side],[(0,1,2,3),(3,2,1,0)],'flower' if i%3==0 else 'leaf')


def chimney(g,x,y,z):
    g.box((x,y,z+.65),(.69,.78,1.55),'stone')
    for zz in np.arange(z+.1,z+1.36,.22):g.box((x,y-.411,zz),(.7,.07,.04),'trim')
    g.box((x,y,z+1.42),(.84,.91,.15),'trim');g.box((x,y,z+1.52),(.63,.7,.06),'shadow')
    for dx in (-.21,.21):g.rings((x+dx,y,z+1.55),[(.14,0),(.13,.29),(.17,.33)],'roof',12)


def dormer(g,x,y,z,shutter):
    small=Geo()
    for l,r,b,t in subtract((-.675,.675,0,1.3),[(-.365,.365,.16,1.11)]):small.box(((l+r)/2,.08,(b+t)/2),(r-l,.16,t-b),'plaster')
    for sx in (-1,1):small.box((sx*.6,.45,.65),(.15,.9,1.3),'plaster')
    small.box((0,.86,.65),(1.35,.14,1.3),'plaster')
    opening(small,0,.16,.73,.95,False,shutter,False)
    small.mesh([(-.67,0,1.3),(.67,0,1.3),(0,0,1.9)],[(0,1,2)],'plaster')
    roof(small,1.3,.9,1.3,.62,'roof');g.add(small,(x,y,z))


def house(w,d,floors,plaster='plaster',shutter='shutter',roofrole='roof',hip=False,doorx=0,balcony_x=None,balcony_floor=1):
    g=Geo();h=.35+floors*2.9;holes_by_face=[]
    for side,(fw,px,py,yaw) in enumerate([(w,0,-d/2,0),(w,0,d/2,180),(d,w/2,0,90),(d,-w/2,0,-90)]):
        face=Geo();holes=[];wins=[]
        count=max(2,round(fw/2.5));xs=[(i-(count-1)/2)*fw/count for i in range(count)]
        if side==0:xs=[xx for xx in xs if abs(xx-doorx)>1.25]
        for floor in range(floors):
            floorxs=xs if floor==0 else [(i-(count-1)/2)*fw/count for i in range(count)]
            if side==0 and floor==balcony_floor and balcony_x is not None:
                floorxs=[xx for xx in floorxs if abs(xx-balcony_x)>1.45]
                zz=.35+floor*2.9;holes.append((balcony_x-.68,balcony_x+.68,zz,zz+2.38));wins.append((balcony_x,zz,1.36,2.38))
            for xx in floorxs:
                z=1.02+floor*2.9;ww=1.02 if floor==0 else 1.12;hh=1.65
                holes.append((xx-ww/2,xx+ww/2,z,z+hh));wins.append((xx,z,ww,hh))
        if side==0:holes.append((doorx-.67,doorx+.67,.35,2.89))
        # Split at the first-floor belt so plaster never replaces a whole lower slab.
        wall(face,fw,h,holes+[],plaster)
        for xx,z,ww,hh in wins:
            opening(face,xx,z,ww,hh,False,None if hh>2 else shutter,True)
            if hh>2:g.box((xx+.1,-.025,z+1.0),(.035,.08,.2),'brass')
        if side==0:
            opening(face,doorx,.35,1.34,2.54,True,None)
            lantern(face,doorx+1.06,-.1,2.16)
            for step in range(3):face.box((doorx,-.27-step*.22,.29-step*.105),(1.86,.75+step*.35,.13),'trim')
            for xx,z,ww,hh in wins:
                if z>3 and abs(xx)>1:flowerbox(face,xx,-.36,z-.30,1.04)
        # Restrained structural posts and roof corbels, avoiding crossed timber clutter.
        for xx in np.linspace(-fw/2+.15,fw/2-.15,count+1):
            if floors>1:face.box((xx,-.035,(3.34+h)/2),(.125,.18,h-3.34),'darkwood')
            face.beam((xx,-.06,h-.6),(xx,-.34,h-.15),.095,'oak')
        g.add(face,(px,py,0),yaw)
        holes_by_face.append(holes)
    g.box((0,0,.14),(w+.36,d+.36,.28),'stone')
    for level in range(1,floors):g.box((0,0,.35+level*2.9),(w+.05,d+.05,.14),'oak')
    rise=w*.48 if not hip else w*.35
    if not hip:
        for sy in (-1,1):
            yy=sy*d/2;gable=Geo()
            # True attic opening in a tapered gable, separated from the main wall.
            for bot,top in [(0,.72),(.72,1.86),(1.86,rise)]:
                if top<=bot:continue
                xb=w*.5*(1-bot/rise);xt=w*.5*(1-top/rise)
                if bot==.72:
                    for sx in (-1,1):gable.mesh([(sx*.47,0,h+bot),(sx*xb,0,h+bot),(sx*xt,0,h+top),(sx*.47,0,h+top)],[(0,1,2,3)],plaster)
                elif top==rise:gable.mesh([(-xb,0,h+bot),(xb,0,h+bot),(0,0,h+rise)],[(0,1,2)],plaster)
                else:gable.mesh([(-xb,0,h+bot),(xb,0,h+bot),(xt,0,h+top),(-xt,0,h+top)],[(0,1,2,3)],plaster)
            opening(gable,0,h+.72,.94,1.14,False,None,True)
            g.add(gable,(0,yy,0),0 if sy<0 else 180)
            if rise>2:g.beam((0,yy,h+1.99),(0,yy,h+rise-.12),.10,'darkwood')
            for sx in (-1,1):g.beam((sx*w/2,yy,h+.02),(0,yy,h+rise),.15,'darkwood')
    roof(g,w,d,h,rise,roofrole,hip)
    chimney(g,-w*.30,d*.17,h+rise*.62)
    # Copper drainpipes: segmented bends and real attachment straps.
    for side in (-1,1):
        xx=side*(w/2+.10);yy=-d/2+.12
        g.beam((xx,yy,.34),(xx,yy,h-.35),.055,'iron')
        g.beam((xx,yy,h-.35),(xx+side*.29,yy,h-.12),.055,'iron')
        for zz in np.arange(.6,h,.95):g.box((xx,yy-.025,zz),(.12,.085,.045),'brass')
    return g,h,rise


def variant(index):
    if index==0:
        g,h,r=house(8.2,6.5,2,balcony_x=0)
        balcony(g,0,-3.29,3.32,2.5,1.13)
        # Dormers face the long side, distinct from the front-gable composition.
        dm=Geo();dormer(dm,0,0,0,'shutter');g.add(dm,(3.1,-1.4,h+1.1),90);g.add(dm,(3.1,1.4,h+1.1),90)
        return g,[[0,0,4.5,8.2,6.5,9]],'Linden Court','菩提庭院宅'
    if index==1:
        g,h,r=house(5.25,6.6,3,'bluewall','blueshutter','slate',balcony_x=0,balcony_floor=2)
        # Projecting enclosed oriel with three faces and a carved support.
        bay=Geo();face=Geo()
        for l,rr,bot,top in subtract((-1.1,1.1,3.82,5.98),[(-.71,.71,4.0,5.65)]):face.box(((l+rr)/2,.04,(bot+top)/2),(rr-l,.20,top-bot),'plaster')
        opening(face,0,4.0,1.42,1.65,False,None,False);bay.add(face,(0,-.83,0))
        for sx in (-1,1):bay.box((sx*1.0,-.35,4.90),(.2,.9,2.16),'plaster')
        bay.box((0,-.35,3.81),(2.3,1,.16),'trim')
        bay.box((0,-.35,6.075),(2.6,1.45,.20),'trim');g.add(bay,(0,-3.45,0))
        for x in (-.72,.72):g.beam((x,-3.38,3.05),(x,-4.15,3.80),.17,'oak')
        balcony(g,0,-3.33,6.22,2.35,1.13)
        return g,[[0,0,5.6,5.25,6.6,11.2]],'Copper Gable','铜檐窄街宅'
    if index==2:
        g,h,r=house(6.4,6.0,2,'rose','shutter')
        wing,wh,wr=house(4.3,5.0,1,'rose','shutter')
        g.add(wing,(4.6,1.0,0),90)
        # Open porch joining both wings; actual columns, not a solid collision slab.
        for x in (2.9,4.9,6.9):
            g.box((x,-2.7,1.53),(.24,.26,2.4),'trim')
            g.box((x,-2.7,.39),(.37,.4,.26),'stone')
        for x in (3.9,5.9):g.arch(x,-2.7,2.10,.86,.18,.24,'trim')
        g.box((4.9,-1.95,3.15),(4.5,1.9,.18),'trim')
        flowerbox(g,4.9,-2.8,3.4,3.6)
        return g,[[0,0,4,6.4,6,8],[4.6,1,2.3,5,4.3,4.6]],'Rose Courtyard','蔷薇花院宅'
    if index==3:
        g,h,r=house(10.4,5.8,2,'sage','blueshutter','roof',True,doorx=-2.7,balcony_x=.5)
        balcony(g,.5,-2.94,3.32,7.7,1.42,True)
        for x in (-3.1,0,3.1):g.beam((x,-4.32,.30),(x,-4.32,3.22),.19,'oak')
        for x in (-2.0,2.0):flowerbox(g,x,-4.38,3.55,1.4)
        return g,[[0,0,4.2,10.4,5.8,8.4]],'Sage Gallery','鼠尾草长廊宅'
    g,h,r=house(7.0,6.3,2,'plaster','blueshutter','slate',doorx=-1.75,balcony_x=-1.25)
    # Trim the main roof against the attached tower before adding that tower.
    # Partition polygons, retaining UVs and colours, instead of overlapping eaves
    # through the taller building's front windows.
    clipped=Geo();vertex_cache={}
    def split(poly,axis,bound):
        low=[];high=[]
        for j,(p,uv,key) in enumerate(poly):
            q,quv,qkey=poly[(j+1)%len(poly)];a=p[axis]-bound;b=q[axis]-bound
            (low if a<=0 else high).append((p,uv,key))
            if a*b<0:
                t=a/(a-b);v=tuple(p[k]+t*(q[k]-p[k]) for k in range(3));u=tuple(uv[k]+t*(quv[k]-uv[k]) for k in range(2))
                edge_key=(tuple(sorted((repr(key),repr(qkey)))),axis,bound)
                low.append((v,u,edge_key));high.append((v,u,edge_key))
        return low,high
    for face,role,uv,color in zip(g.f,g.roles,g.uv,g.colors):
        poly=[(g.v[vi],co,vi) for vi,co in zip(face,uv)]
        if min(v[0][2] for v in poly)<h-.26:
            pieces=[poly]
        else:
            west,east=split(poly,0,1.96);south,north=split(east,1,.35) if len(east)>2 else ([],[])
            pieces=[west,north]
        for piece in pieces:
            if len(piece)<3:continue
            indices=[]
            for p,co,key in piece:
                if key not in vertex_cache:vertex_cache[key]=len(clipped.v);clipped.v.append(p)
                indices.append(vertex_cache[key])
            clipped.f.append(tuple(indices));clipped.roles.append(role);clipped.uv.append([co for p,co,key in piece]);clipped.colors.append(color)
    g=clipped
    flashing_z=h+r*(1-1.96/(7.0/2+.43))+.07
    g.beam((1.97,-3.56,flashing_z),(1.97,.34,flashing_z),.065,'iron')
    tower,th,tr=house(3.6,3.6,3,'plaster','blueshutter','slate',True)
    g.add(tower,(3.8,-1.65,0))
    balcony(g,-1.25,-3.20,3.32,2.45,1.12)
    # Roof finial and restrained blue ceramic corner crest.
    g.rings((3.8,-1.65,th+tr+.2),[(.17,0),(.09,.18),(.04,.68),(0,.84)],'brass',16)
    return g,[[0,0,4.4,7,6.3,8.8],[3.8,-1.65,5.7,3.6,3.6,11.4]],'Azure Corner','青瓷转角宅'


def main():
    global MAPS,R
    bpy.ops.wm.read_factory_settings(use_empty=True);OUT.mkdir(parents=True,exist_ok=True)
    print('RESIDENCES_TEXTURES_START',flush=True);MAPS=textures()
    manifest={'id':'floor1_residences_5','source':'original procedural geometry and PBR textures','unit':'metre','interiors':'unfurnished shell; closed doors; no resident housing state','textures':{'resolution':2048,'sets':4,'maps':['sRGB albedo','OpenGL tangent normal','linear ORM (R=1,G=roughness,B=0)'],'metric_repeat_m':2.0},'assets':[]}
    for i in range(5):
        R=random.Random(411+i*313);geo,proxies,label,zh=variant(i)
        asset_id=f'F1_Residence_{i+1:02d}';print('RESIDENCE_BUILD '+asset_id+' faces='+str(len(geo.f)),flush=True)
        col=bpy.data.collections.new(asset_id);bpy.context.scene.collection.children.link(col)
        bpy.ops.object.select_all(action='DESELECT');ob=geo.object(asset_id+'_LOD0',col)
        entry={'id':asset_id,'label':label,'label_zh':zh,'collision_boxes_blender_xyz':proxies,'lods':[]}
        objects=[ob]
        for level,ratio in [(1,.42),(2,.16)]:
            lo=ob.copy();lo.data=ob.data.copy();lo.name=asset_id+f'_LOD{level}';col.objects.link(lo)
            bpy.context.view_layer.objects.active=lo;mod=lo.modifiers.new('Distance simplification','DECIMATE');mod.ratio=ratio;mod.use_collapse_triangulate=True
            bpy.ops.object.modifier_apply(modifier=mod.name);objects.append(lo)
        for level,obj in enumerate(objects):
            # Collapse can leave invalid loops and float32-scale sliver faces.
            obj.data.validate(clean_customdata=False)
            bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.triangulate(bm,faces=list(bm.faces))
            bad=[face for face in bm.faces if face.calc_area()<1e-8]
            if bad:bmesh.ops.delete(bm,geom=bad,context='FACES_ONLY')
            bm.to_mesh(obj.data);bm.free();obj.data.update()
            # Reserve a separate atlas strip for the thin faces Smart Project
            # collapses (mostly leadwork and bevel slivers). UV0 is untouched.
            uv=obj.data.uv_layers[1].data
            collapsed=[]
            for poly in obj.data.polygons:
                a,b,c=[uv[li].uv.copy() for li in poly.loop_indices]
                if abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))<1e-9:collapsed.append(poly)
            for corner in uv:corner.uv.y=.15+corner.uv.y*.85
            cols=max(1,math.ceil(math.sqrt(len(collapsed)/.13)));rows=max(1,math.ceil(len(collapsed)/cols))
            for j,poly in enumerate(collapsed):
                for li,(u,v) in zip(poly.loop_indices,[(.15,.15),(.85,.15),(.15,.85)]):uv[li].uv=((j%cols+u)/cols,(j//cols+v)*.13/rows)
            obj['secondary_uv_repaired_thin_triangles']=len(collapsed)
            obj.data.calc_loop_triangles()
            entry['lods'].append({'level':level,'triangles':len(obj.data.loop_triangles),'surfaces':len(obj.data.materials),'vertices':len(obj.data.vertices)})
            obj['lod']=level
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:obj.select_set(True)
        path=OUT/(asset_id+'.glb')
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_extras=True,export_yup=True,export_apply=True,export_normals=True,export_texcoords=True,export_tangents=True,export_vertex_color='ACTIVE',export_all_vertex_colors=False)
        entry['file']=path.relative_to(ROOT).as_posix();entry['sha256']=hashlib.sha256(path.read_bytes()).hexdigest();entry['bytes']=path.stat().st_size
        bounds=[Vector(v) for v in ob.bound_box];entry['dimensions_blender_xyz_m']=[round(max(v[a] for v in bounds)-min(v[a] for v in bounds),4) for a in range(3)]
        for obj in objects:obj.location=(i*15,0,0);obj.hide_render=obj!=ob;obj.hide_viewport=obj!=ob
        manifest['assets'].append(entry);print('RESIDENCE_EXPORTED '+json.dumps(entry,ensure_ascii=False),flush=True)
    # Source is a usable five-house line-up, with packed textures and organised LODs.
    bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'Floor1_Residences_5.blend'),compress=True)
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('RESIDENCES_COMPLETE',flush=True)


if __name__=='__main__':main()
