"""Author original edible sushi cars and a toy light rail with actual Blender bpy.

Run: Blender --background --factory-startup --threads 4 --python THIS -- [--no-render]
Coordinates are Blender Z-up, forward -Y. glTF exports Godot Y-up, forward +Z.
No download, GUI control, scene gameplay objects, or third-party model assets.
"""
from __future__ import annotations
import bpy, math, json, hashlib, struct, sys
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/trains'
SOURCE = ROOT / 'art_source/trains'
KEYS = ['sushi_gunkan','sushi_salmon','sushi_tuna','sushi_shrimp','sushi_eel',
        'sushi_tamago','sushi_roe','sushi_mackerel','rail_cab','rail_car']
LABELS = ['Gunkan Engine','Salmon','Tuna','Shrimp','Glazed Eel','Tamago','Salmon Roe','Mackerel','Light Rail Cab','Light Rail Car']
C = dict(rice='#fff6dd', grain='#fffcf0', nori='#163d2b', nori_light='#32613a',
         wheel='#263b40', wood='#dca158', salmon='#ff7141', fat='#ffd4a1',
         tuna='#ee4260', tuna_dark='#c92346', shrimp='#ff875b', cream='#fff2c5',
         eel='#8f4023', sauce='#f3af49', egg='#ffd23c', toast='#f59a30',
         roe='#ff6a19', roe_light='#ffb044', silver='#dae8eb', blue='#2c77a2',
         white='#effbfa', teal='#23b8c3', glass='#183f69', reflection='#94dcf4',
         orange='#ff9643', dark='#344b60')

def rgba(hex_color):
    rgb=[int(hex_color[i:i+2],16)/255 for i in (1,3,5)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)

def setup():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for material in list(bpy.data.materials):bpy.data.materials.remove(material)
    m=bpy.data.materials.new('Train_Vertex_Glaze');m.use_nodes=True;m.use_backface_culling=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value=.32
    bs.inputs['Metallic'].default_value=0
    bs.inputs['Coat Weight' if 'Coat Weight' in bs.inputs else 'Clearcoat'].default_value=.18
    bs.inputs['Coat Roughness' if 'Coat Roughness' in bs.inputs else 'Clearcoat Roughness'].default_value=.23
    vc=m.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Color'
    m.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
    return m

class Builder:
    def __init__(self,key,material):self.key=key;self.parts=[];self.material=material
    def finish_part(self,obj,color,tag,smooth=False):
        obj.name=self.key+'__'+tag
        if obj.data.materials:obj.data.materials.clear()
        obj.data.materials.append(self.material)
        attr=obj.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
        for item in attr.data:item.color=rgba(C.get(color,color))
        for p in obj.data.polygons:p.use_smooth=smooth
        self.parts.append(obj);return obj
    def box(self,p,size,color,tag,bevel=.04,segments=2,rot=0):
        bpy.ops.mesh.primitive_cube_add(size=1,location=p)
        o=bpy.context.object;o.dimensions=size
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        if bevel:
            mod=o.modifiers.new('Rounded food edges','BEVEL');mod.width=min(bevel,min(size)*.45);mod.segments=segments
            bpy.ops.object.modifier_apply(modifier=mod.name)
        o.rotation_euler.z=rot
        if bevel:
            for face in o.data.polygons:face.use_smooth=True
            if hasattr(o.data,'use_auto_smooth'):o.data.use_auto_smooth=True
            weighted=o.modifiers.new('Broad smooth face normals','WEIGHTED_NORMAL');weighted.keep_sharp=True
            bpy.ops.object.modifier_apply(modifier=weighted.name)
        return self.finish_part(o,color,tag,smooth=bool(bevel))
    def ellipsoid(self,p,size,color,tag,n=8,rings=4,rot=0):
        verts=[(0,0,-.5)];faces=[]
        for j in range(1,rings):
            a=math.pi*j/rings
            for i in range(n):
                b=math.tau*i/n;verts.append((.5*math.sin(a)*math.cos(b),.5*math.sin(a)*math.sin(b),-.5*math.cos(a)))
        top=len(verts);verts.append((0,0,.5))
        for i in range(n):faces.append((0,1+(i+1)%n,1+i))
        for j in range(rings-2):
            lo=1+j*n;hi=lo+n
            for i in range(n):faces.append((lo+i,lo+(i+1)%n,hi+(i+1)%n,hi+i))
        lo=1+(rings-2)*n
        for i in range(n):faces.append((lo+i,lo+(i+1)%n,top))
        vs=[(x*size[0],y*size[1],z*size[2]) for x,y,z in verts]
        return self.poly(vs,faces,p,color,tag,smooth=True,rot=rot)
    def poly(self,verts,faces,p,color,tag,smooth=False,rot=0):
        me=bpy.data.meshes.new(self.key+'_'+tag);me.from_pydata(verts,[],faces);me.update()
        o=bpy.data.objects.new(self.key+'_'+tag,me);bpy.context.collection.objects.link(o)
        o.location=p;o.rotation_euler.z=rot
        return self.finish_part(o,color,tag,smooth)
    def cyl(self,p,r,depth,color,tag,n=10,axis='Z'):
        bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=depth,end_fill_type='NGON',location=p)
        o=bpy.context.object
        if axis=='X':o.rotation_euler.y=math.pi/2
        return self.finish_part(o,color,tag)
    def oval_shell(self,z,height,width,length,color,tag):
        # Four rounded elliptical rings: bevelled lower/upper silhouette.
        rings=[(z,.88),(z+.055,1),(z+height-.055,1),(z+height,.88)]
        verts=[];n=16
        for h,r in rings:
            for i in range(n):
                a=math.tau*i/n;verts.append((math.cos(a)*width*.5*r,math.sin(a)*length*.5*r,h))
        faces=[tuple(reversed(range(n))),tuple(range((len(rings)-1)*n,len(rings)*n))]
        for j in range(len(rings)-1):
            for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
        return self.poly(verts,faces,(0,0,0),color,tag)
    def ribbon(self,coords,width,z,color,tag):
        # Thin closed marbling ribbon, resting directly against topping surface.
        v=[]
        for x,y in coords:v.extend([(x,y-width*.5,z),(x,y+width*.5,z)])
        f=[(i*2,i*2+2,i*2+3,i*2+1) for i in range(len(coords)-1)]
        return self.poly(v,f,(0,0,0),color,tag)
    def panel(self,p,size,color,tag,axis='X',sign=1,radius=.04):
        # Rounded colored glazing/trim uses a planar perimeter, not six bevelled
        # faces per sticker. It is an authored mesh surface, not a texture.
        w,h=size;r=min(radius,w*.45,h*.45);v=[]
        for u,z,start in [(w*.5-r,h*.5-r,0),(-w*.5+r,h*.5-r,90),(-w*.5+r,-h*.5+r,180),(w*.5-r,-h*.5+r,270)]:
            for j in range(3):
                a=math.radians(start+j*45);q=(u+r*math.cos(a),z+r*math.sin(a))
                v.append((0,q[0],q[1]) if axis=='X' else (q[0],0,q[1]))
        face=tuple(range(len(v)))
        if sign<0:face=tuple(reversed(face))
        return self.poly(v,[face],p,color,tag)
    def join(self):
        bpy.ops.object.select_all(action='DESELECT')
        for p in self.parts:p.select_set(True)
        bpy.context.view_layer.objects.active=self.parts[0];bpy.ops.object.join()
        o=bpy.context.object;o.name=self.key
        # Bake all original part transforms into a single original mesh.
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        # Explicit triangulation produces a inspectable stable game resource.
        mod=o.modifiers.new('Game triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
        o.data.name=self.key+'_Mesh';o.data.materials.clear();o.data.materials.append(self.material)
        for p in o.data.polygons:p.material_index=0
        return o

def wheels(b,rail=False):
    x=.568 if rail else .465;y=.70 if rail else .43;r=.14 if rail else .115
    for side in [-1,1]:
        for end in [-1,1]:
            b.cyl((side*x,end*y,r),r,.105 if rail else .085,'wheel','Wheel',n=10,axis='X')
            b.cyl((side*(x+.054 if rail else x+.044),end*y,r),r*.43,.008,'wood' if not rail else 'teal','Hub',n=8,axis='X')
    for side in [-1,1]:
        b.box((0,side*(1.025 if rail else .735),.20 if rail else .18),(.25,.10,.09),'dark' if rail else 'nori','Coupler',bevel=.015,segments=1)

def sushi_base(b,nori=False):
    wheels(b)
    b.box((0,0,.19),(.87,1.35,.14),'wood','Bamboo underframe',.045,1)
    if nori:
        b.oval_shell(.25,.46,.91,1.31,'nori','Seaweed wrap')
        b.ellipsoid((0,0,.69),(.80,1.17,.14),'rice','Rice crown',n=12,rings=3)
        for side in [-1,1]:
            for y in [-.34,0,.34]:
                b.box((side*(.445-.025*abs(y)),y,.46),(.012,.035,.25),'nori_light','Nori grain',0,1)
    else:
        b.box((0,0,.40),(.88,1.28,.43),'rice','Rounded rice pillow',.135,2)
        # Small separate grains silhouette the otherwise inexpensive rice pillow.
        for side in [-1,1]:
            for i in range(5):
                y=-.44+i*.22;x=side*(.431-.035*abs(y)/.44)
                b.ellipsoid((x,y,.42+(.025 if i%2 else -.025)),(.067,.17,.105),'grain','Rice grain',n=6,rings=3,rot=side*.13)

def salmon(b):
    b.box((0,0,.692),(1.01,1.43,.26),'salmon','Salmon fillet',.105,2)
    for i in range(6):
        y=-.47+i*.18
        b.ribbon([(-.385,y-.065),(-.19,y-.015),(0,y+.04),(.19,y-.015),(.385,y-.065)],.035,.824,'fat','Salmon fat chevron')

def tuna(b):
    b.box((0,0,.696),(1.0,1.42,.27),'tuna','Tuna loin',.095,2)
    for side in [-1,1]:
        for j in range(3):
            y=-.37+j*.32
            b.ribbon([(side*.03,y+.10),(side*.18,y+.03),(side*.39,y-.075)],.018,.833,'fat','Tuna grain')
    b.ribbon([(0,-.54),(.035,0),(.015,.53)],.020,.834,'tuna_dark','Loin division')

def shrimp(b):
    for i in range(6):
        y=-.47+i*.175;width=.76-.045*i
        b.ellipsoid((0,y,.67+.035*math.sin(i*.65)),(width,.29,.25),'shrimp' if i%2==0 else 'fat','Shrimp segment',n=10,rings=4)
    for side in [-1,1]:
        b.poly([(0,0,0),(side*.31,.25,-.02),(side*.34,.06,.03),(side*.08,-.09,.015)],[(3,2,1,0) if side>0 else (0,1,2,3)],(0,.49,.66),'salmon','Shrimp tail fan')

def eel(b):
    b.box((0,0,.676),(.91,1.45,.245),'eel','Grilled eel',.10,2)
    for i in range(7):
        y=-.52+i*.17
        b.ribbon([(-.35,y-.025),(-.18,y+.045),(0,y),(.20,y+.035),(.35,y-.02)],.04,.800,'sauce','Glaze stripe')
    for x,y in [(-.21,-.37),(.17,.04),(-.08,.36)]:b.ellipsoid((x,y,.816),(.065,.105,.023),'cream','Sesame',n=6,rings=3,rot=.6)

def tamago(b):
    b.box((0,0,.722),(.99,1.40,.33),'egg','Sweet omelette',.085,2)
    for y in [-.46,.44]:b.box((0,y,.89),(.67,.07,.007),'toast','Golden omelette seam',.003,1)
    b.box((0,0,.894),(1.004,.26,.016),'nori','Nori top belt',.006,1)
    for side in [-1,1]:b.box((side*.497,0,.69),(.018,.26,.40),'nori','Nori belt side',.008,1)

def roe(b,engine=False):
    # Nine translucent-looking orange pearls have lit geometry, not a flat decal.
    pts=[(-.23,-.34),(.04,-.35),(.25,-.18),(-.27,-.06),(0,-.08),(.22,.14),(-.23,.23),(0,.33),(.04,.08)]
    if engine:pts=pts[:5]
    for i,(x,y) in enumerate(pts):
        b.ellipsoid((x,y,.79),(.255,.255,.255),'roe' if i%3 else 'roe_light','Salmon roe',n=8,rings=4)
    if engine:
        b.box((0,.30,.86),(.66,.42,.37),'nori','Engine sushi cab',.05,2)
        b.box((0,.080,.90),(.42,.018,.13),'cream','Engine cream cab window',.025,1)
        for side in [-1,1]:b.box((side*.337,.29,.91),(.018,.23,.12),'fat','Engine side window',.02,1)
        b.cyl((0,-.42,1.04),.105,.34,'nori_light','Cucumber chimney',n=12)
        b.cyl((0,-.42,1.212),.095,.012,'cream','Cucumber cut top',n=12)
        b.cyl((0,-.42,1.22),.058,.012,'nori_light','Cucumber seed core',n=8)

def mackerel(b):
    b.box((0,0,.688),(.98,1.42,.25),'silver','Silver mackerel fillet',.11,2)
    b.ribbon([(-.34,-.47),(-.19,-.44),(0,-.43),(.19,-.44),(.34,-.47)],.14,.816,'blue','Blue shoulder')
    for i in range(5):
        y=-.29+i*.17
        b.ribbon([(-.365,y-.05),(-.20,y+.015),(0,y-.005),(.20,y+.015),(.365,y-.05)],.046,.817,'blue','Mackerel skin stripe')

def rail(b,cab):
    wheels(b,rail=True)
    b.box((0,0,.30),(1.05,1.95,.22),'dark','Rail chassis',.07,1)
    if cab:
        # Front is -Y, visibly sloping from lower nose to panoramic windshield.
        yz=[(-1.01,.39),(-1.035,.76),(-.82,1.19),(.86,1.19),(.98,1.02),(.98,.39)]
        vs=[(x,y,z) for x in [-.59,.59] for y,z in yz]
        n=len(yz);faces=[tuple(range(n)),tuple(reversed(range(n,2*n)))]+[(i+n,(i+1)%n+n,(i+1)%n,i) for i in range(n)]
        b.poly(vs,faces,(0,0,0),'white','Sloped rail cab')
        # Windshield sits on the sloped front surface and inherits its incline.
        b.poly([(-.48,-1.024,.795),(.48,-1.024,.795),(.48,-.861,1.12),(-.48,-.861,1.12)],[(0,1,2,3)],(0,0,0),'glass','Panoramic windshield')
        b.poly([(-.38,-1.013,.824),(-.19,-1.013,.824),(.18,-.894,1.062),(-.03,-.894,1.062)],[(0,1,2,3)],(0,0,0),'reflection','Windshield sky reflection')
        for x in [-.38,.38]:b.panel((x,-1.038,.64),(.23,.07),'cream','Headlight',axis='Y',radius=.025)
    else:
        b.box((0,0,.79),(1.18,1.95,.88),'white','Rounded rail passenger body',.10,2)
        for end in [-1,1]:b.box((0,end*.979,.77),(.45,.018,.66),'dark','Gangway',.05,1)
    b.box((0,.05,1.22),(1.08,1.76,.15),'teal','Rounded roof',.07,2)
    b.box((0,.30,1.322),(.56,.60,.056),'white','Roof cooling unit',.025,1)
    for side in [-1,1]:
        x=side*.598
        b.panel((side*.609,.06,.49),(1.73,.16),'teal','Side teal waist',sign=side,radius=.007)
        b.panel((side*.610,.06,.62),(1.71,.045),'orange','Service orange stripe',sign=side,radius=.006)
        for y in [-.49,.03,.55]:
            b.panel((side*.612,y,.91),(.40,.32),'glass','Passenger window',sign=side,radius=.06)
            b.panel((side*.614,y-.085,.949),(.07,.20),'reflection','Window sky reflection',sign=side,radius=.018)
        # The central narrow door remains visually separate from the windows.
        for y in [-.24,.25]:
            b.panel((side*.616,y,.75),(.018,.60),'dark','Door boundary',sign=side,radius=.005)
        b.panel((side*.618,.012,.724),(.035,.11),'dark','Door handle',sign=side,radius=.005)

def bounds(obj):
    v=[obj.matrix_world@p.co for p in obj.data.vertices]
    mins=[min(p[i] for p in v) for i in range(3)];maxs=[max(p[i] for p in v) for i in range(3)]
    # glTF exporter rotation (x,y,z Blender) -> (x,z,-y Godot).
    godot_min=[mins[0],mins[2],-maxs[1]];godot_max=[maxs[0],maxs[2],-mins[1]]
    return {'min':godot_min,'max':godot_max,'size':[godot_max[i]-godot_min[i] for i in range(3)]}

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def glb_info(path):
    data=path.read_bytes();magic,version,length=struct.unpack_from('<III',data)
    assert magic==0x46546c67 and version==2 and length==len(data)
    n,t=struct.unpack_from('<II',data,12);assert t==0x4e4f534a
    return json.loads(data[20:20+n])

def export_asset(o):
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    p=OUT/(o.name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(p),export_format='GLB',use_selection=True,
        export_yup=True,export_apply=True,export_materials='EXPORT',
        export_animations=False,export_cameras=False,export_lights=False)
    g=glb_info(p);prims=[p for me in g['meshes'] for p in me['primitives']]
    tris=sum(g['accessors'][p['indices']]['count']//3 for p in prims)
    assert tris<=1500,(o.name,tris)
    assert len(g.get('materials',[]))==1 and len(prims)==1
    assert not g.get('textures') and not g.get('images')
    assert all('COLOR_0' in p['attributes'] for p in prims)
    box=bounds(o);size=box['size']
    assert abs(box['min'][1])<1e-5
    assert abs(box['min'][0]+box['max'][0])<1e-5 and abs(box['min'][2]+box['max'][2])<1e-5
    if o.name.startswith('sushi'):
        assert size[0]<=1.06 and size[2]<=1.58 and size[1] <= (1.3 if o.name=='sushi_gunkan' else 1.1)
    else:assert size[0]<=1.26 and size[2]<=2.16 and size[1]<=1.36
    return dict(key=o.name,file='res://assets/trains/'+p.name,sha256=sha(p),bytes=p.stat().st_size,
        bounds=box,triangles=tris,material_surfaces=len(prims),materials=len(g['materials']),
        vertices=sum(g['accessors'][p['attributes']['POSITION']]['count'] for p in prims),
        embedded_texture_bytes=0,forward=[0,0,1],base_y=0,
        source_object=o.name,semantic='engine' if o.name=='sushi_gunkan' else 'cab' if o.name=='rail_cab' else 'car')

def render_contact(objects):
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.render.resolution_x=1800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
    scene.view_settings.view_transform='Standard'
    scene.world.color=(.70,.70,.70)
    scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.70,.77,.88,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
    floor=bpy.data.materials.new('Render_only_Backdrop');floor.diffuse_color=(.88,.93,.98,1);floor.use_nodes=True
    floor.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.88,.93,.98,1)
    floor.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.025));ground=bpy.context.object;ground.name='RENDER_ONLY_Backdrop';ground.data.materials.append(floor)
    text_mat=bpy.data.materials.new('Render_only_Type');text_mat.diffuse_color=(.028,.064,.10,1)
    for i,o in enumerate(objects):
        o.location=((i%5-2)*2.95,2.6 if i<5 else -2.2,0);o.rotation_euler.z=-.30
        bpy.ops.object.text_add(location=(o.location.x,o.location.y-1.8,.005))
        t=bpy.context.object;t.name='RENDER_ONLY_Label';t.data.body=LABELS[i];t.data.align_x='CENTER';t.data.size=.20;t.data.extrude=0;t.data.materials.append(text_mat)
    data=bpy.data.cameras.new('RENDER_ONLY_Camera');cam=bpy.data.objects.new('RENDER_ONLY_Camera',data);scene.collection.objects.link(cam)
    cam.location=(0,-18,24);target=Vector((0,-.30,0));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=16.1;scene.camera=cam
    for name,p,power,size in [('Key',(-5,-8,13),1500,9),('Fill',(7,3,10),1000,8)]:
        ld=bpy.data.lights.new('RENDER_ONLY_'+name,'AREA');ld.energy=power;ld.shape='DISK';ld.size=size
        light=bpy.data.objects.new(ld.name,ld);scene.collection.objects.link(light);light.location=p;light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(SOURCE/'contact-sheet.png');bpy.ops.render.render(write_still=True)


def main():
    OUT.mkdir(parents=True,exist_ok=True);SOURCE.mkdir(parents=True,exist_ok=True)
    mat=setup();objects=[];rows=[]
    for key in KEYS:
        b=Builder(key,mat)
        if key.startswith('sushi'):
            sushi_base(b,nori=key in ['sushi_gunkan','sushi_roe'])
            if key=='sushi_gunkan':roe(b,True)
            elif key=='sushi_roe':roe(b)
            else:globals()[key.removeprefix('sushi_')](b)
        else:rail(b,key=='rail_cab')
        o=b.join()
        # Stable source mesh origin: centered XZ after glTF conversion, floor Y=0.
        box=bounds(o);offset=Vector((-(box['min'][0]+box['max'][0])*.5,(box['min'][2]+box['max'][2])*.5,-box['min'][1]))
        for v in o.data.vertices:v.co+=offset
        o.data.update();objects.append(o);rows.append(export_asset(o))
        print('TRAIN_ASSET',key,rows[-1]['triangles'],rows[-1]['bounds']['size'],flush=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    # Authoring scene holds each base-origin asset, arranged only for browsing.
    for i,o in enumerate(objects):o.location=((i%5)*3,(i//5)*4,0)
    bpy.context.preferences.filepaths.save_version=0
    bpy.context.scene['authoring']='Original procedural Blender bpy geometry; no imported models or textures.'
    bpy.context.scene['contract']='Each exported car is independent; +Z forward in Godot; XZ centered and baseY0.'
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'train_assets.blend'),compress=True)
    manifest={'schema':1,'authoring_tool':'Blender '+bpy.app.version_string,'blender_build_hash':bpy.app.build_hash.decode(),
        'generator':'tools/build_train_assets.py','generator_sha256':sha(Path(__file__)),
        'source':'art_source/trains/train_assets.blend','source_sha256':sha(SOURCE/'train_assets.blend'),
        'license':'Original project-authored geometry and palette; no downloaded assets.',
        'coordinate_contract':{'godot_up':'+Y','godot_forward':'+Z','blender_up':'+Z','blender_forward':'-Y','origin':'XZ center at ground Y=0','units':'meters'},
        'limits':{'max_triangles_per_asset':1500,'max_material_surfaces':4,'actual_shared_material_surfaces':1},
        'assets':rows,'total_glb_bytes':sum(r['bytes'] for r in rows)}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    if '--no-render' not in sys.argv:render_contact(objects)
    print('TRAIN_ASSETS_COMPLETE',len(rows),manifest['total_glb_bytes'],flush=True)
if __name__=='__main__':main()
