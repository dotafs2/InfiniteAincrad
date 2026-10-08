"""Author original glacial cliff families in Blender; no external meshes/textures.

Broad calving faces, offset snow shelves and rounded fracture edges replace
conical crystal props. All parts are closed, bevels applied, one vertex-colour
material per exported family. Blender Z-up -> glTF Y-up exactly once.
"""
import bpy, bmesh, math, json, hashlib, random
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/frost'; SOURCE=ROOT/'art_source/frostlight'
PALETTE={'ice':(.115,.48,.68,1),'frost':(.27,.67,.83,1),'deep':(.055,.27,.46,1),'snow':(.79,.91,.98,1)}

def finished_mesh(name, verts, faces, snow=False):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
    bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    mod=obj.modifiers.new('Weathered fracture edge','BEVEL');mod.width=.006 if snow else .011;mod.segments=2
    mod.affect='EDGES';mod.limit_method='ANGLE';mod.angle_limit=.40
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(MAT)
    col=obj.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for p in obj.data.polygons:
        if snow:c=PALETTE['snow']
        else:
            weight=max(0,min(1,.5+p.normal.x*.25-p.normal.y*.28+p.normal.z*.12))
            a,b=PALETTE['deep'],PALETTE['frost']
            c=tuple(a[k]*(1-weight)+b[k]*weight for k in range(3))+(1,)
        for li in p.loop_indices:col.data[li].color=c
    obj.select_set(False)
    return obj

def solid(name, polygon, height, base, lean, seed):
    n=len(polygon);cx=sum(p[0] for p in polygon)/n;cy=sum(p[1] for p in polygon)/n
    slope=.18 if height>.55 else .09
    tops=[height*(.90+slope*math.cos(i*math.tau/n+seed*.57)+.075*math.sin(i*2.5+seed)) for i in range(n)]
    rings=[(0.,1.,0.),(.22,1.01,.15),(.60,.85,.50),(1.,.70,1.)]
    verts=[]
    for ri,(fraction,scale,shift) in enumerate(rings):
        for i,(x,y) in enumerate(polygon):
            # Fracture shoulders are offset at each elevation, with coherent
            # sloping caps and steep planar ice faces rather than vertical boxes.
            facet=1.+.08*math.sin(i*3.+seed+ri*.75)*fraction
            z=base+(tops[i]-base)*fraction
            verts.append((cx+(x-cx)*scale*facet+lean[0]*shift,
                          cy+(y-cy)*scale*facet+lean[1]*shift,z))
    faces=[tuple(reversed(range(n)))]
    for r in range(3):
        for i in range(n):faces.append((r*n+i,r*n+(i+1)%n,(r+1)*n+(i+1)%n,(r+1)*n+i))
    summit=(cx+lean[0]-.045,cy+lean[1]+.028,max(tops)*1.025)
    verts.append(summit)
    for i in range(n):faces.append((3*n+i,3*n+(i+1)%n,len(verts)-1))
    return finished_mesh(name,verts,faces), verts[3*n:4*n], summit

def snow_mantle(name, perimeter, summit, seed):
    n=len(perimeter);cx=sum(v[0] for v in perimeter)/n;cy=sum(v[1] for v in perimeter)/n
    # Frost runs down selected faces. Every upper vertex follows the authored
    # ice cap; the lower rim penetrates it, leaving no separate white lid.
    lower=[];upper=[]
    for i,(x,y,z) in enumerate(perimeter):
        depth=.024+.070*(.5+.5*math.sin(i*2.8+seed))
        lower.append((cx+(x-cx)*1.025,cy+(y-cy)*1.025,z-depth))
        upper.append((cx+(x-cx)*1.025,cy+(y-cy)*1.025,z+.020))
    verts=lower+upper+[(summit[0],summit[1],summit[2]+.024)]
    faces=[tuple(reversed(range(n)))]
    for i in range(n):
        j=(i+1)%n;faces.append((i,j,n+j,n+i));faces.append((n+i,n+j,2*n))
    return finished_mesh(name,verts,faces,True)

def footprint(cx,cy,w,d,seed):
    rng=random.Random(seed)
    coords=[(-.5,-.30),(-.32,-.5),(.32,-.5),(.5,-.25),(.48,.30),(.24,.5),(-.36,.48),(-.5,.18)]
    return [(cx+x*w*(1+rng.uniform(-.07,.07)),cy+y*d*(1+rng.uniform(-.07,.07))) for x,y in coords]

def chunk(parts, name, x,y,w,d,h,seed,base=0, snow=True):
    obj,top,z=solid(name,footprint(x,y,w,d,seed),h,base,(.08*math.sin(seed),.06*math.cos(seed)),seed)
    parts.append(obj)
    if snow:
        # Snow intersects the actual upper ice surface, so no floating caps.
        cap=snow_mantle(name+' snow mantle',top,z,seed)
        parts.append(cap)

def build_family(name):
    parts=[]
    if name=='glacier':
        # Broad, stepped calving wall with contrasting vertical fracture gaps.
        for i,(x,y,w,d,h) in enumerate([(-.36,.13,.38,.68,.70),(-.04,.16,.39,.63,1.02),(.28,.14,.36,.64,.84),(-.25,-.24,.42,.45,.40),(.17,-.27,.49,.39,.28)]):
            chunk(parts,'Calving cliff %02d'%i,x,y,w,d,h,21+i)
    elif name=='glacier_ridge':
        for i,(x,y,w,d,h) in enumerate([(-.37,.10,.34,.56,.42),(-.13,.04,.35,.66,.82),(.16,.13,.33,.54,1.1),(.36,.07,.25,.48,.63),(.10,-.30,.40,.30,.26)]):
            chunk(parts,'Windcut ridge %02d'%i,x,y,w,d,h,60+i)
    elif name=='glacier_shelf':
        for i,(x,y,w,d,h) in enumerate([(0,.13,1.02,.70,.68),(-.16,-.16,.80,.50,.40),(.14,-.32,.70,.32,.20),(.30,.28,.32,.34,.83)]):
            chunk(parts,'Calved shelf %02d'%i,x,y,w,d,h,100+i)
    elif name=='glacier_serac':
        for i,(x,y,w,d,h) in enumerate([(-.22,.09,.48,.60,.66),(.18,.14,.49,.56,.94),(.02,-.24,.54,.38,.36)]):
            chunk(parts,'Split serac %02d'%i,x,y,w,d,h,140+i)
    elif name=='ice_rock':
        chunk(parts,'Blue ice boulder',-.04,.0,.84,.73,.46,178)
        chunk(parts,'Broken toe',.29,-.20,.43,.42,.19,183,snow=False)
    elif name=='ice_floe':
        chunk(parts,'Pancake floe',0,0,1.,.83,.22,195)
        chunk(parts,'Floe fracture',.29,.07,.37,.38,.34,196)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts:ob.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join()
    obj=bpy.context.object;obj.name=name
    # Normalize presentation assets to a measured floor-centred unit envelope.
    lo=Vector(tuple(min(v.co[k] for v in obj.data.vertices) for k in range(3)))
    hi=Vector(tuple(max(v.co[k] for v in obj.data.vertices) for k in range(3)))
    extent=hi-lo;centre=(lo+hi)*.5
    for v in obj.data.vertices:
        v.co.x=(v.co.x-centre.x)/extent.x;v.co.y=(v.co.y-centre.y)/extent.y;v.co.z=(v.co.z-lo.z)/extent.z
    obj.data.update()
    bm=bmesh.new();bm.from_mesh(obj.data)
    invalid=sum(not e.is_manifold for e in bm.edges);bm.free()
    assert invalid==0,(name,invalid)
    obj.data.calc_loop_triangles();triangles=len(obj.data.loop_triangles)
    path=OUT/(name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,
        export_materials='EXPORT',export_extras=True)
    obj.select_set(False)
    return {'id':name,'path':'res://assets/frost/'+path.name,'triangles':triangles,'closed_edges':True,
        'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'unit_bounds':[1,1,1]}

def main():
    global MAT
    OUT.mkdir(parents=True,exist_ok=True);SOURCE.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MAT=bpy.data.materials.new('Glacial ice and frost vertex palette');MAT.use_nodes=True
    bs=MAT.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.19;bs.inputs['Metallic'].default_value=0
    bs.inputs['Coat Weight'].default_value=.2
    colour=MAT.node_tree.nodes.new('ShaderNodeVertexColor');colour.layer_name='Color'
    MAT.node_tree.links.new(colour.outputs['Color'],bs.inputs['Base Color'])
    assets=[build_family(n) for n in ['glacier','glacier_ridge','glacier_shelf','glacier_serac','ice_rock','ice_floe']]
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'frostlight_assets.blend'),compress=True)
    manifest={'schema':2,'authoring_tool':'Blender','blender_version':bpy.app.version_string,'assets':assets,
     'reference_policy':'Original procedural meshes. Frozen 2 official ice look/lighting research informs material hierarchy only. No copied characters, imagery, meshes, layouts, or textures.',
     'source_blend':'art_source/frostlight/frostlight_assets.blend','source_blend_sha256':hashlib.sha256((SOURCE/'frostlight_assets.blend').read_bytes()).hexdigest()}
    (SOURCE/'asset-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('FROST_BLENDER_ASSETS '+json.dumps(manifest))
if __name__=='__main__':main()
