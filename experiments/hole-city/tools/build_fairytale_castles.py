"""Original Sunspell royal toy architecture, authored and saved in Blender 4.2.

Run only in an allocated Blender process:
  Blender --background --factory-startup --python this_file.py -- --out DIR
No download, external model, texture or image-generation input is used.
The editable Blender components are exported as one indexed, opaque vertex-color
game mesh per kind, with normalized compound hull points for major masses only.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
import bmesh
from mathutils import Vector, Matrix

KINDS = ("toy_castle", "grand_castle", "bubble_turret", "toy_arch", "block_tower")
BUDGETS = {"toy_castle": 12000, "grand_castle": 12000, "bubble_turret": 6000,
           "toy_arch": 2500, "block_tower": 6000}
# Exact preceding Godot envelopes. Fit evaluated authored vertices into these
# sizes before export: runtime/frozen-world collision admission shares them.
NATURAL_SIZES = {
    "toy_castle": (5.0952001, 5.9173999, 3.7676001),
    "grand_castle": (6.5471997, 7.79, 4.4756002),
    "bubble_turret": (2.3232, 6.0834999, 2.3232),
    "toy_arch": (3.1500001, 4.5, 1.17),
    "block_tower": (2.78, 5.0679998, 2.3699999),
}
COLORS = {"stone": "f6e8bb", "stone_trim": "fff5d6", "roof": "20a8a5",
          "roof_dark": "167878", "wood": "ed7990", "glass": "294963",
          "gold": "f6be48", "banner": "df4163", "paving": "80cbb8",
          "roof_cobalt": "315b9f", "roof_blue_trim": "689ec5",
          "gate_recess": "172e3b", "gate_door": "405867"}
ROLES = list(COLORS)
OBJECTS = {}
COLLECTION = None
MATERIALS = {}


def digest(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as file:
        for block in iter(lambda: file.read(1048576), b""):
            h.update(block)
    return h.hexdigest()


def rgb(hex_color):
    return tuple(int(hex_color[i:i+2], 16)/255 for i in (0, 2, 4))


def linear(v):
    return v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4


def material(role):
    if role in MATERIALS:
        return MATERIALS[role]
    m = bpy.data.materials.new("Fairytale_"+role)
    m.use_nodes = True
    node = m.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (*[linear(v) for v in rgb(COLORS[role])], 1)
    node.inputs["Roughness"].default_value = .23 if role.startswith("roof") else .28
    node.inputs["Metallic"].default_value = .38 if role == "gold" else 0
    node.inputs["Coat Weight"].default_value = .42
    m.diffuse_color = (*[linear(v) for v in rgb(COLORS[role])], 1)
    MATERIALS[role] = m
    return m


def mesh_object(name, vertices, faces, role, smooth=False, collision=None, bevel=0):
    mesh = bpy.data.meshes.new(name+"_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    # Each primitive is a closed solid. Recalculate outward normals without
    # filling openings or duplicating front/back shells of the same surface.
    bm = bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh); bm.free()
    obj = bpy.data.objects.new(name, mesh)
    COLLECTION.objects.link(obj)
    mesh.materials.append(material(role))
    for face in mesh.polygons:
        face.use_smooth = smooth
    if bevel:
        modifier = obj.modifiers.new("Handcrafted edge bevel", "BEVEL")
        modifier.width = bevel; modifier.segments = 1
        modifier.affect = "EDGES"; modifier.limit_method = "ANGLE"
        modifier.angle_limit = .5
    obj["fairytale_role"] = role
    obj["collision_mass"] = collision or "decoration"
    obj["original_recipe"] = True
    obj["structural_role"] = "detail"
    OBJECTS.setdefault(COLLECTION.name, []).append(obj)
    return obj


def box(name, at, size, role, bevel=.035, collision=None, yaw=0):
    half = [v/2 for v in size]
    vertices = [(sx*half[0], sy*half[1], sz*half[2]) for sx, sy, sz in
                [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                 (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    faces = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    obj = mesh_object(name, vertices, faces, role, bevel=bevel, collision=collision)
    obj.location = at; obj.rotation_euler.z = yaw
    return obj


def lathe(name, at, profile, role, sides=16, collision=None):
    # Radius/height profile with unique pole fans, closed end caps and no
    # degenerate duplicated-pole rings. Curved eaves have real thickness.
    vertices, rings, faces = [], [], []
    for radius, height in profile:
        if radius == 0:
            rings.append([len(vertices)]); vertices.append((0,0,height))
        else:
            rings.append(list(range(len(vertices), len(vertices)+sides)))
            vertices.extend((radius*math.cos(i*math.tau/sides), radius*math.sin(i*math.tau/sides), height) for i in range(sides))
    for a,b in zip(rings,rings[1:]):
        for i in range(sides):
            j = (i+1)%sides
            if len(a)==1: faces.append((a[0],b[j],b[i]))
            elif len(b)==1: faces.append((a[i],a[j],b[0]))
            else: faces.append((a[i],a[j],b[j],b[i]))
    obj = mesh_object(name, vertices, faces, role, smooth=True, collision=collision)
    obj.location = at
    return obj


def extruded_outline(name, outline, depth, at, role, collision=None, bevel=0):
    # A single closed extruded polygon, including concave U-shaped arch frames.
    n = len(outline)
    vertices = [(x,-depth/2,z) for x,z in outline]+[(x,depth/2,z) for x,z in outline]
    faces = [tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    obj = mesh_object(name, vertices, faces, role, collision=collision, bevel=bevel)
    obj.location = at
    return obj


def arch_outline(width, height, steps=7):
    r = width/2; spring = height-r
    return [(-r,0),(r,0)]+[(r*math.cos(a),spring+r*math.sin(a)) for a in [i*math.pi/steps for i in range(steps+1)]]


def arch_panel(name, center_x, front, base, width, height, role, depth=.045):
    return extruded_outline(name, arch_outline(width,height), depth, (center_x,front,base), role)


def window(name, x, front, base, width=.44, height=.79):
    arch_panel(name+" cream plastic window frame", x,front,base,width+.15,height+.12,"stone_trim",.075)
    arch_panel(name+" inset blue glass",x,front-.045,base+.055,width,height,"glass",.048)
    box(name+" mullion",(x,front-.081,base+height*.49),(.032,.035,height*.71),"gold",0)
    box(name+" sill",(x,front-.087,base-.015),(width+.24,.14,.095),"stone_trim",0)


def wall_window(name, at, width, height, yaw):
    # Secondary elevations use closed low-cost surrounds rather than blank
    # walls. Rotate the complete authored window assembly, not its normals.
    start=len(OBJECTS[COLLECTION.name])
    arch_panel(name+" cream plastic window frame",0,-.025,0,width+.15,height+.12,"stone_trim",.065)
    arch_panel(name+" recessed glass",0,-.064,.055,width,height,"glass",.038)
    box(name+" slim mullion",(0,-.093,height*.49),(.029,.025,height*.71),"gold",0)
    box(name+" slim sill",(0,-.088,-.015),(width+.20,.115,.075),"stone_trim",0)
    for obj in OBJECTS[COLLECTION.name][start:]:
        x,y,z=obj.location
        obj.location=(at[0]+x*math.cos(yaw)-y*math.sin(yaw),
                      at[1]+x*math.sin(yaw)+y*math.cos(yaw),at[2]+z)
        obj.rotation_euler.z+=yaw


def stud(name, at, radius=.10, height=.095):
    # Eight-sided connectors retain round silhouettes at their tiny screen size.
    obj=lathe(name,at,[(0,0),(radius,0),(radius,height),(0,height)],"stone_trim",8)
    obj["structural_role"]="stud"
    return obj


def modular_walls(name, width, depth, height, at, mass):
    # Closed snap-together shell bricks with real air joints and staggered end
    # pieces. The inset closed core gives the assembled body a solid interior.
    thickness=.18
    # The fully enclosed core needs closed geometry, not invisible edge bevels.
    box(name+" inset plastic core",(at[0],at[1],at[2]+height/2),(width-2*thickness-.06,depth-2*thickness-.06,height-.025),"stone",0,mass)
    courses=4
    for row in range(courses):
        h=height/courses;z=at[2]+(row+.5)*h
        for axis,length,columns in (("front",width,3),("back",width,3),("east",depth-2*thickness-.035,2),("west",depth-2*thickness-.035,2)):
            step=length/columns
            cuts=[-length/2]
            shift=.5 if row%2 else 1.0
            v=-length/2+step*shift
            while v<length/2-.001:cuts.append(v);v+=step
            cuts.append(length/2)
            for index,(lo,hi) in enumerate(zip(cuts,cuts[1:])):
                center=(lo+hi)/2;span=hi-lo-.018
                role="wood" if row==1 else ("stone_trim" if row%2 else "stone")
                if axis in ("front","back"):
                    pos=(at[0]+center,at[1]+(-1 if axis=="front" else 1)*(depth/2-thickness/2),z)
                    size=(span,thickness,h-.026)
                else:
                    pos=(at[0]+(-1 if axis=="west" else 1)*(width/2-thickness/2),at[1]+center,z)
                    size=(thickness,span,h-.026)
                brick=box(name+" %s course%d brick%d"%(axis,row,index),pos,size,role,.022,mass)
                brick["structural_role"]="block_course";brick["course_index"]=row;brick["wall_side"]=axis;brick["assembly_surface"]=axis


def roof(name, at, width, depth, rise, role="roof", collision=None):
    # Several closed curved gable panels assemble along the roof ridge. Their
    # narrow geometric joints stay visible without a painted texture.
    section=[(-width*.5,0),(-width*.43,.08*rise),(-width*.30,.39*rise),
             (-width*.14,.81*rise),(0,rise),(width*.14,.81*rise),
             (width*.30,.39*rise),(width*.43,.08*rise),(width*.5,0),
             (width*.46,-.12),(-width*.46,-.12)]
    panels=4 if collision is not None else 2
    first=None
    for index in range(panels):
        low=-depth/2+index*depth/panels+(.014 if index else 0)
        high=-depth/2+(index+1)*depth/panels-(.014 if index<panels-1 else 0)
        obj=extruded_outline(name+" snap panel%d"%index,section,high-low,(at[0],at[1]+(low+high)/2,at[2]),role,collision)
        obj["structural_role"]="gable_panel"
        for face in obj.data.polygons:face.use_smooth=len(face.vertices)==4
        bm=bmesh.new();bm.from_mesh(obj.data)
        for edge in bm.edges:
            if len(edge.link_faces)==2 and (any(not face.smooth for face in edge.link_faces) or edge.calc_face_angle(0)>1.30):edge.smooth=False
        bm.to_mesh(obj.data);bm.free()
        if collision is not None:
            bevel=obj.modifiers.new("Rounded plastic panel edge", "BEVEL")
            bevel.width=.012;bevel.segments=1;bevel.limit_method="ANGLE";bevel.angle_limit=1.30
        first=first or obj
    return first


def cone_roof(name, at, radius, rise, collision, role="roof_cobalt"):
    # A curved slate-like cap with two real, closed overlapping eave rings.
    # Broad silhouette changes replace tiny texture detail at phone scale.
    profile=[(0,-.055),(radius*.88,-.055),(radius,0),
             (radius*.95,.075*rise),(radius*.75,.25*rise),
             (radius*.59,.46*rise),(radius*.38,.68*rise),
             (radius*.16,.88*rise),(0,rise)]
    lathe(name+" curved crown",at,profile,role,12,collision)
    for index,(height,width) in enumerate(((.08,.95),(.43,.62))):
        r=radius*width
        lathe(name+" overlapping eave ring%d"%index,(at[0],at[1],at[2]+rise*height),
              [(0,0),(r*.98,0),(r*1.05,.035),(r*.99,.072),(0,.072)],
              "roof_blue_trim" if role=="roof_cobalt" else "roof_dark",12)
    lathe(name+" golden finial",(at[0],at[1],at[2]+rise-.02),
          [(0,0),(.062,.028),(.086,.11),(.047,.17),(0,.29)],"gold",8)


def turret(name, at, radius, height, mass, roof_role="roof_cobalt", foot_studs=True, roof_rise=None):
    # Four stacked injection-moulded turret modules: shallow waists and actual
    # separation reveal how the tower clips together rather than stone masonry.
    courses=4
    for index in range(courses):
        h=(height-.04)/courses
        obj=lathe(name+" stacked tower module%d"%index,(at[0],at[1],at[2]+index*h+.012),
                  [(0,0),(radius*.96,0),(radius,h*.13),(radius*.91,h*.82),(radius*.96,h-.024),(0,h-.024)],
                  "wood" if index==1 else ("stone_trim" if index%2 else "stone"),12,mass)
        obj["structural_role"]="tower_segment";obj["course_index"]=index;obj["assembly_surface"]=name
    lathe(name+" snap cornice",(at[0],at[1],at[2]+height-.19),
          [(0,0),(radius,0),(radius*1.10,.05),(radius*1.10,.14),(radius,.19),(0,.19)],"stone_trim",12,mass)
    platform=lathe(name+" connection foot",at,[(0,0),(radius*1.16,0),(radius*1.16,.18),(0,.18)],"paving",12,mass)
    platform["structural_role"]="plastic_frame"
    for index in range(4 if foot_studs else 0):
        angle=(index+.5)*math.tau/4
        stud(name+" foot stud%d"%index,(at[0]+radius*1.02*math.cos(angle),at[1]+radius*1.02*math.sin(angle),at[2]+.18),radius*.15,.12)
    cone_roof(name+" glazed snap spire",(at[0],at[1],at[2]+height),radius*1.32,
              height*.43 if roof_rise is None else roof_rise,mass,roof_role)
    for index in range(4):
        angle=index*math.pi/2
        wall_window(name+" elevation%d lancet"%index,
                    (at[0]+math.sin(angle)*radius*.94,at[1]-math.cos(angle)*radius*.94,at[2]+height*.48),
                    radius*.53,min(height*.25,.85),angle)


def banner(name, at, width=.32, height=.85):
    outline = [(-width/2,height),(width/2,height),(width*.52,.23),(0,0),(-width*.52,.23)]
    extruded_outline(name+" folded swallowtail",outline,.032,at,"banner")
    box(name+" brass hanger",(at[0],at[1],at[2]+height+.02),(width+.16,.065,.065),"gold",.01)


def dormer(name, at, width=.62, assembly_scale=1.0):
    first=len(OBJECTS[COLLECTION.name])
    box(name+" cream cheeks",(at[0],at[1],at[2]+.34),(width,.49,.68),"stone_trim",.025)
    roof(name+" tiny pitched cap",(at[0],at[1],at[2]+.72),width+.20,.66,.46)
    arch_panel(name+" glass",at[0],at[1]-.264,at[2]+.09,width*.60,.51,"glass",.03)
    if assembly_scale!=1.0:
        origin=Vector(at)
        for obj in OBJECTS[COLLECTION.name][first:]:
            obj.location=origin+(obj.location-origin)*assembly_scale
            obj.scale*=assembly_scale


def keep(name, width, depth, height, at=(0,0,0), timber=False, mass="keep"):
    modular_walls(name,width,depth,height,at,mass)
    plinth=box(name+" studded foundation plate",(at[0],at[1],at[2]+.12),(width+.36,depth+.50,.24),"paving",.025,mass)
    plinth["structural_role"]="plastic_frame"
    for side in (-1,1):
        for index in range(6):
            stud(name+" foundation stud%d-%d"%(side,index),(at[0]+(index-2.5)*width/6,at[1]+side*(depth/2+.10),at[2]+.24),.135,.13)
    front = at[1]-depth/2-.045
    for level in range(2):
        for x in (-width*.29,width*.29):
            window(name+" floor%d window%.1f"%(level,x),at[0]+x,front,at[2]+.68+level*height*.42,width*.16,height*.23)
    for level in range(2):
        base=at[2]+.67+level*height*.42
        wall_window(name+" east window%d"%level,(at[0]+width/2+.045,at[1],base),depth*.23,height*.25,math.pi/2)
        wall_window(name+" west window%d"%level,(at[0]-width/2-.045,at[1],base),depth*.23,height*.25,-math.pi/2)
        wall_window(name+" rear window%d"%level,(at[0],at[1]+depth/2+.045,base),width*.21,height*.25,math.pi)
    arch_panel(name+" clip door surround",at[0],front-.012,at[2]+.18,.83,1.44,"stone_trim",.11)
    arch_panel(name+" coral plastic door",at[0],front-.076,at[2]+.21,.66,1.29,"wood",.045)
    box(name+" door brass handle",(at[0]+.16,front-.11,at[2]+.74),(.06,.06,.12),"gold",.016)
    box(name+" snap eaves",(at[0],at[1],at[2]+height-.08),(width+.22,depth+.23,.20),"stone_trim",.032,mass)
    roof(name+" sweeping gable",(at[0],at[1],at[2]+height+.035),width+.53,depth+.52,height*.52,collision=mass)
    dormer(name+" left dormer",(at[0]-width*.23,at[1]-depth*.37,at[2]+height+.41),width*.23)
    dormer(name+" right dormer",(at[0]+width*.23,at[1]-depth*.37,at[2]+height+.41),width*.23)
    for x in (-width*.41,width*.41):banner(name+" heraldry",(at[0]+x,front-.11,at[2]+height*.58),width*.10,height*.24)
    if timber:
        for x in (-width*.44,0,width*.44):
            frame=box(name+" vertical plastic frame",(at[0]+x,front-.025,at[2]+height*.51),(.105,.065,height*.94),"wood",.013)
            frame["structural_role"]="plastic_frame"
        for z in (height*.42,height*.78):
            frame=box(name+" plastic crossbar",(at[0],front-.063,at[2]+z),(width+.02,.065,.11),"wood",.013)
            frame["structural_role"]="plastic_frame"
        for sign in (-1,1):
            beam = box(name+" plastic diagonal snap brace",(at[0]+sign*width*.22,front-.071,at[2]+height*.61),(.095,.055,height*.39),"wood",.008)
            beam.rotation_euler.y = sign*.61
            beam["structural_role"]="plastic_frame"


def balcony(name, at, width=1.15, yaw=0):
    start=len(OBJECTS[COLLECTION.name])
    box(name+" cantilever tray",(0,-.15,0),(width,.43,.10),"stone_trim",.015)
    box(name+" upper rail",(0,-.34,.32),(width,.06,.085),"gold",0)
    for x in (-width*.46,-width*.23,0,width*.23,width*.46):
        box(name+" rail spindle",(x,-.34,.17),(.045,.048,.30),"stone_trim",0)
    for sign in (-1,1):
        box(name+" side rail",(sign*width*.46,-.17,.32),(.06,.34,.085),"gold",0)
    for obj in OBJECTS[COLLECTION.name][start:]:
        x,y,z=obj.location
        obj.location=(at[0]+x*math.cos(yaw)-y*math.sin(yaw),
                      at[1]+x*math.sin(yaw)+y*math.cos(yaw),at[2]+z)
        obj.rotation_euler.z+=yaw


def parapet(name, width, depth, z, center=(0,0)):
    # Closed ledges and raised merlons give the low keep a readable terrace.
    for side in (-1,1):
        box(name+" long coping",(center[0],center[1]+side*depth*.5,z),(width+.13,.15,.13),"stone_trim",0)
        for index in range(5):
            box(name+" merlon",(center[0]+(index-2)*width*.21,center[1]+side*depth*.5,z+.14),(.21,.16,.24),"stone_trim",0)
        box(name+" short coping",(center[0]+side*width*.5,center[1],z),(.15,depth,.13),"stone_trim",0)


def royal_gate_front(name, width, height, front):
    # Closed U-shaped portal, not an opaque pale panel hiding a door pasted on
    # its front. The dark door sits physically behind the projecting surround.
    r=width*.5;inner=r-.105;spring=height-r;steps=9
    outer=[(-r,0),(-r,spring)]+[(r*math.cos(a),spring+r*math.sin(a)) for a in [math.pi-i*math.pi/steps for i in range(1,steps+1)]]+[(r,0)]
    inside=[(inner,0),(inner,spring)]+[(inner*math.cos(a),spring+inner*math.sin(a)) for a in [i*math.pi/steps for i in range(1,steps+1)]]+[(-inner,0)]
    extruded_outline(name+" projecting open portal",outer+inside,.16,(0,front,.17),"stone_trim")
    arch_panel(name+" shaded entrance recess",0,front+.035,.23,width-.18,height-.105,"gate_recess",.035)
    arch_panel(name+" inset double doors",0,front+.015,.26,width-.35,height-.25,"gate_door",.040)
    box(name+" door meeting stile",(0,front-.025,.80),(.03,.025,1.06),"gold",0)
    for x in (-width*.19,width*.19):
        box(name+" gold door boss",(x,front-.025,.80),(.045,.025,.075),"gold",0)
    # A custom four-point jewel is project heraldry, not a borrowed crest.
    extruded_outline(name+" sun diamond crest",[(0,.24),(.13,.10),(0,-.06),(-.13,.10)],.07,
                     (0,front-.13,height+.16),"gold")


def castle(grand=False):
    name="Sunspell Palace" if grand else "Rosewater Keep"
    width,depth,height=(3.70,2.65,2.40) if grand else (3.0,2.20,1.95)
    radius=.61 if grand else .49
    # The low, wide assembled base supports a stepped keep and one dominant
    # slender spire. Four unequal flanks keep the skyline from reading as a box
    # with identical corner cones.
    modular_walls(name+" lower keep",width,depth,height,(0,0,.08),"central_keep")
    plate=box(name+" assembled foundation",(0,0,.12),(width+.38,depth+.50,.24),"paving",.025,"central_keep")
    plate["structural_role"]="plastic_frame"
    for side in (-1,1):
        for index in range(6):
            stud(name+" terrace connector%d-%d"%(side,index),((index-2.5)*width/6,side*(depth/2+.10),.24),.11,.12)
    parapet(name+" lower terrace",width,depth,height+.11)
    front=-depth/2-.065
    royal_gate_front(name,width*.37,height*.83,front)
    for sign in (-1,1):
        window(name+" lower front lancet",sign*width*.35,front,.81,width*.12,height*.40)
        wall_window(name+" side gallery",(sign*(width/2+.045),0,.81),depth*.21,height*.43,sign*math.pi/2)
        wall_window(name+" rear court window",(sign*width*.27,depth/2+.045,.81),width*.15,height*.43,math.pi)
        banner(name+" gate silk",(sign*width*.20,front-.11,height*.54),.23,height*.34)
        # Long chamfered corner buttresses read as snapped supporting pieces.
        for y in (-depth*.28,depth*.28):
            frame=box(name+" corner buttress",(sign*(width*.5+.05),y,height*.41),(.20,.28,height*.82),"stone_trim",.025)
            frame["structural_role"]="plastic_frame"
    # A narrow upper keep makes the central entrance rise above the parapet.
    upper_width=width*.53;upper_depth=depth*.64;upper_height=1.24 if grand else .96
    upper_base=height-.08
    box(name+" upper rose hall",(0,.12,upper_base+upper_height*.5),(upper_width,upper_depth,upper_height),"wood",.03,"central_keep")
    box(name+" upper cream cornice",(0,.12,upper_base+upper_height),(upper_width+.20,upper_depth+.18,.17),"stone_trim",.018,"central_keep")
    roof(name+" upper sweeping roof",(0,.12,upper_base+upper_height+.07),upper_width+.38,upper_depth+.28,.82 if grand else .63,"roof",collision="central_keep")
    window(name+" high balcony door",0,.12-upper_depth/2-.04,upper_base+.14,.48,upper_height*.69)
    balcony(name+" ceremonial balcony",(0,.12-upper_depth/2-.055,upper_base+.10),1.03 if grand else .89)
    wall_window(name+" upper rear lancet",(0,.12+upper_depth/2+.035,upper_base+.14),.48,upper_height*.69,math.pi)
    offsets=[(-width*.635,-depth*.47),(width*.635,-depth*.47),
             (-width*.635,depth*.47),(width*.635,depth*.47)]
    heights=[2.67,3.25,4.15,3.58] if grand else [2.10,2.57,3.22,2.83]
    for i,((x,y),h) in enumerate(zip(offsets,heights)):
        turret(name+" corner%d"%i,(x,y,0),radius*(.91 if i==0 else 1.0),h,"corner%d"%i,
               "roof" if i in (0,3) else "roof_cobalt",roof_rise=h*.37)
    central_base=3.50 if grand else 2.60
    turret(name+" crown tower",(0,.37,central_base),.60 if grand else .46,
           3.0 if grand else 2.30,"crown_tower","roof_cobalt",False,1.45 if grand else 1.14)
    # One genuinely half-scale dormer sits into the sloping roof. Scale its
    # height and depth as well as width so it cannot compete with the crown.
    dormer(name+" upper side dormer",(-upper_width*.27,-upper_depth*.22,
           upper_base+upper_height+(.44 if grand else .36)),.40,.50)
    for step in range(3):
        box(name+" entry step%d"%step,(0,-depth/2-.25-step*.18,.065+step*.035),(1.35,.25,.13+step*.07),"paving",.018)


def gate():
    # A genuine through arch. All detail is attached to its legs or above the
    # opening; local x=0,y=.25, z=-.8..+.8 stays clear after normalization.
    width,height,thick,depth = 2.8,3.65,.34,.86
    r=width/2;spring=height-r;inner=r-thick
    outer=[(-r,0),(-r,spring)]+[(r*math.cos(a),spring+r*math.sin(a)) for a in [math.pi-i*math.pi/12 for i in range(1,13)]]+[(r,0)]
    inside=[(inner,0),(inner,spring)]+[(inner*math.cos(a),spring+inner*math.sin(a)) for a in [i*math.pi/12 for i in range(1,13)]]+[(-inner,0)]
    obj=extruded_outline("Moonbridge open arch",outer+inside,depth,(0,0,0),"stone",collision="arch_segments")
    obj["split_arch_collision"] = True
    for x in (-r+thick/2,r-thick/2):
        box("Moonbridge leg plinth",(x,0,.13),(thick+.24,depth+.19,.26),"stone_trim",.025)
        for index in range(3):
            collar=box("Moonbridge leg snap course%d"%index,(x,0,.62+index*.55),(thick+.11,depth+.10,.085),"stone_trim",.014)
            collar["structural_role"]="tower_segment";collar["course_index"]=index;collar["assembly_surface"]="left_leg" if x<0 else "right_leg"
        for index in range(2):
            for side in (-1,1):
                stud("Moonbridge base stud",(x+(index-.5)*.18,side*.47,.26),.075,.105)
        banner("Moonbridge pennant",(x,-depth*.58,1.28),.19,.73)
        box("Moonbridge rose gate pier",(x,-depth*.51,1.08),(thick*.63,.065,1.72),"wood",.014)
        banner("Moonbridge reverse pennant",(x,depth*.58,1.28),.19,.73)
        cone_roof("Moonbridge flanking crown",(x,0,2.18),.25,.67,None,"roof_cobalt")
    roof("Moonbridge curved crest",(0,0,height+.055),width+.35,depth+.31,.51)
    lathe("Moonbridge star finial",(0,0,height+.58),[(0,0),(.085,.06),(.035,.18),(0,.27)],"gold",10)
    obj["arch_inner_radius"] = inner;obj["arch_spring"] = spring


def build_kind(kind):
    global COLLECTION
    COLLECTION=bpy.data.collections.new(kind)
    bpy.context.scene.collection.children.link(COLLECTION)
    if kind=="toy_castle":castle(False)
    elif kind=="grand_castle":castle(True)
    elif kind=="bubble_turret":
        turret("Starlight Watchtower",(0,0,0),.88,3.85,"watchtower")
        balcony("Starlight sentry balcony",(0,-.77,1.81),.94)
        for sign in (-1,1):
            banner("Starlight side pennant",(sign*.43,-.78,.46),.19,.84)
    elif kind=="toy_arch":gate()
    elif kind=="block_tower":
        keep("Gingerbeam Townhouse",2.25,1.85,3.3,timber=True,mass="townhouse")
        balcony("Gingerbeam royal gallery",(0,-1.02,1.53),1.08)
        for sign in (-1,1):
            box("Gingerbeam rose chimney",(sign*.79,.49,4.15),(.26,.29,1.04),"wood",.02,"townhouse")
            box("Gingerbeam chimney cap",(sign*.79,.49,4.65),(.38,.40,.13),"stone_trim",.015)
    return COLLECTION


def fit_natural_envelope(kind):
    # Bake modifiers and fit real authored vertices, including ornamentation.
    # This is a measured geometry transform, never a substituted size label.
    deps=bpy.context.evaluated_depsgraph_get();points=[]
    for obj in OBJECTS[kind]:
        evaluated=obj.evaluated_get(deps);mesh=evaluated.to_mesh()
        points.extend(obj.matrix_world@v.co for v in mesh.vertices)
        evaluated.to_mesh_clear()
    low=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    target=Vector((NATURAL_SIZES[kind][0],NATURAL_SIZES[kind][2],NATURAL_SIZES[kind][1]))
    scale=Vector(tuple(target[i]/(high[i]-low[i]) for i in range(3)))
    center=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
    transform=Matrix.Diagonal((*scale,1.0))
    for obj in OBJECTS[kind]:
        evaluated=obj.evaluated_get(deps)
        mesh=bpy.data.meshes.new_from_object(evaluated)
        mesh.transform(obj.matrix_world)
        for vertex in mesh.vertices:
            original=vertex.co.copy()
            vertex.co=transform@(original-center)
            # Snap only measured extreme vertices to their corresponding
            # fitted extrema, avoiding accumulated float32 envelope drift.
            for axis in range(3):
                if abs(original[axis]-low[axis])<1e-7:vertex.co[axis]=0.0 if axis==2 else -target[axis]/2
                elif abs(original[axis]-high[axis])<1e-7:vertex.co[axis]=target[axis] if axis==2 else target[axis]/2
        if obj.get("split_arch_collision",False):
            obj["arch_inner_radius"]*=scale.x
            obj["arch_spring"]=(float(obj["arch_spring"])-low.z)*scale.z
        obj.modifiers.clear();obj.data=mesh;obj.matrix_world=Matrix.Identity(4);mesh.update()
        obj["natural_envelope_restored"]=True
    bpy.context.view_layer.update()


def godot(p):
    return Vector((p.x,p.z,-p.y))


def export_kind(kind,out):
    deps=bpy.context.evaluated_depsgraph_get()
    vertices,normals,roles,indices=[],[],[],[]
    components=[]
    lookup={};masses={};all_points=[]
    for obj in OBJECTS[kind]:
        evaluated=obj.evaluated_get(deps);mesh=evaluated.to_mesh()
        mesh.calc_loop_triangles()
        normal_matrix=obj.matrix_world.to_3x3().inverted().transposed()
        role=ROLES.index(obj["fairytale_role"])
        points=[godot(obj.matrix_world @ v.co) for v in mesh.vertices]
        all_points.extend(points)
        group=obj["collision_mass"]
        if group!="decoration":
            if obj.get("split_arch_collision",False):
                spring=float(obj["arch_spring"]);inner=float(obj["arch_inner_radius"])
                masses["left_leg"]=[p for p in points if p.x<=-inner+.001 and p.y<=spring+.001]
                masses["right_leg"]=[p for p in points if p.x>=inner-.001 and p.y<=spring+.001]
                masses["arch_crown"]=[p for p in points if p.y>=spring-.001]
            else:masses.setdefault(group,[]).extend(points)
        component_start=len(indices)
        for tri in mesh.loop_triangles:
            triangle=[]
            for loop_index in tri.loops:
                loop=mesh.loops[loop_index]
                p=points[loop.vertex_index]
                n=godot(normal_matrix @ mesh.corner_normals[loop_index].vector).normalized()
                key=tuple(round(v,7) for v in (*p,*n,role))
                if key not in lookup:
                    lookup[key]=len(vertices);vertices.append(list(p));normals.append(list(n));roles.append(role)
                triangle.append(lookup[key])
            a,b,c=[Vector(vertices[i]) for i in triangle]
            assert (b-a).cross(c-a).length>1e-9,"Degenerate exported face in "+obj.name
            indices.extend((triangle[0],triangle[2],triangle[1]))  # Godot clockwise fronts.
        components.append({"name":obj.name,"structural_role":obj["structural_role"],
                           "material_role":obj["fairytale_role"],"index_start":component_start,
                           "index_count":len(indices)-component_start,"triangle_count":(len(indices)-component_start)//3,
                           "course_index":obj.get("course_index",-1),"wall_side":obj.get("wall_side",""),"assembly_surface":obj.get("assembly_surface",""),
                           "world_low":[min(p[i] for p in points) for i in range(3)],
                           "world_high":[max(p[i] for p in points) for i in range(3)]})
        evaluated.to_mesh_clear()
    low=Vector(tuple(min(p[i] for p in all_points) for i in range(3)))
    high=Vector(tuple(max(p[i] for p in all_points) for i in range(3)))
    size=high-low;origin=Vector(((low.x+high.x)/2,low.y,(low.z+high.z)/2))
    def normalize(p):return [round((p[i]-origin[i])/size[i],7) for i in range(3)]
    for component in components:
        lo=normalize(component.pop("world_low"));hi=normalize(component.pop("world_high"))
        component["unit_bounds"]={"position":lo,"size":[round(hi[i]-lo[i],7) for i in range(3)]}
    vertices=[normalize(p) for p in vertices]
    normals=[list(Vector((n[0]*size.x,n[1]*size.y,n[2]*size.z)).normalized()) for n in normals]
    normals=[[round(v,7) for v in n] for n in normals]
    parts=[]
    for name,points in masses.items():
        unique=sorted(set(tuple(normalize(p)) for p in points))
        assert len(unique)>=4,"Insufficient closed major mass "+name
        parts.append({"name":name,"points":[list(p) for p in unique]})
    if len(parts)>7 or len(indices)//3>BUDGETS[kind]:
        print("FAIRYTALE_BUDGET_FAILURE "+json.dumps({"kind":kind,"triangles":len(indices)//3,"budget":BUDGETS[kind],"largest_components":sorted(components,key=lambda c:c["triangle_count"],reverse=True)[:12]}),flush=True)
    assert len(parts)<=7 and len(indices)//3<=BUDGETS[kind],(kind,len(parts),len(indices)//3)
    colors=[[*rgb(COLORS[ROLES[role]]),1] for role in roles]
    geometry_sha=hashlib.sha256(json.dumps([vertices,indices],separators=(',',':')).encode()).hexdigest()
    payload={"schema":1,"kind":kind,"authoring_tool":"Blender","blender_version":bpy.app.version_string,
             "coordinates":"Godot Y-up, +Z front; clockwise indexed triangles",
             "natural_size":[round(v,7) for v in size],"vertices":vertices,"normals":normals,
             "colors":colors,"color_roles":roles,"role_names":ROLES,"indices":indices,
             "collision_parts":parts,"components":components,"source_geometry_sha256":geometry_sha,
             "unit_aabb":{"position":[-.5,0,-.5],"size":[1,1,1]},
             "arch_opening_probe":{"from":[0,.25,-.8],"to":[0,.25,.8],"expected_clear":True} if kind=="toy_arch" else None}
    assert tuple(payload["natural_size"])==NATURAL_SIZES[kind],("Actual envelope changed",kind,payload["natural_size"],NATURAL_SIZES[kind])
    path=out/(kind+".json");path.write_text(json.dumps(payload,separators=(',',':'))+'\n')
    return {"path":"res://assets/fairytale_castles/"+path.name,"sha256":digest(path),
            "source_geometry_sha256":geometry_sha,"triangles":len(indices)//3,"vertices":len(vertices),
            "natural_size":payload["natural_size"],"collision_parts":len(parts),"component_objects":len(OBJECTS[kind]),"structural_counts":{role:sum(c["structural_role"]==role for c in components) for role in sorted(set(c["structural_role"] for c in components))},
            "triangle_budget":BUDGETS[kind],"arch_opening_probe":payload["arch_opening_probe"]}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out",type=Path,required=True)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
    assert not (out/"manifest.json").exists(),"Preserve the previous authored asset generation"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rows={}
    for kind in KINDS:
        build_kind(kind);fit_natural_envelope(kind);rows[kind]=export_kind(kind,out)
        print("FAIRYTALE_ASSET "+json.dumps({"kind":kind,**rows[kind]}),flush=True)
    # Arrange the editable source catalog only after exporting its local meshes.
    for index,kind in enumerate(KINDS):
        parent=bpy.data.objects.new(kind+"_Editable_Assembly",None)
        bpy.context.scene.collection.objects.link(parent)
        for obj in OBJECTS[kind]:obj.parent=parent
        parent.location.x=(index-2)*9.5
    scene=bpy.context.scene;scene.render.engine="BLENDER_EEVEE_NEXT"
    scene.world=bpy.data.worlds.new("Fairytale neutral studio")
    scene.world.use_nodes=True;scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.16,.19,.25,1)
    source=out/"source";source.mkdir(exist_ok=True);(source/".gdignore").write_text("")
    blend=source/"fairytale_castles.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
    manifest={"schema":1,"name":"Original Sunspell Royal Snap-Together Castle Kit","authoring_tool":"Blender",
              "blender_version":bpy.app.version_string,"generator":"tools/build_fairytale_castles.py",
              "generator_sha256":digest(Path(__file__)),"blender_binary_sha256":digest(bpy.app.binary_path),
              "source_blend":"source/fairytale_castles.blend","source_blend_sha256":digest(blend),
              "license":"Original project-authored geometry; no third-party models or textures",
              "runtime_format":"Indexed normalized unit mesh, real corner normals, opaque RGBA vertex colors, role IDs, major compound hull points",
              "kinds":list(KINDS),"assets":rows,"rendered_or_gameplay_verified":False}
    (out/"manifest.json").write_text(json.dumps(manifest,indent=2)+'\n')
    print("FAIRYTALE_BUILD "+json.dumps({"assets":len(rows),"triangles":sum(x["triangles"] for x in rows.values()),"source_blend_sha256":manifest["source_blend_sha256"]}),flush=True)


if __name__=="__main__":main()
