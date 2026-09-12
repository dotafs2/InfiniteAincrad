"""Original shopfront attachment kit. Blender 5.x. Run from any directory.

Geometry is in metres, Z-up, facade facing -Y. Origin is wall plane Y=0,
at the bottom centre of each attachment (roof pieces use their base level).
All recipe geometry is original; minimal local helpers derive from the
project's StreetStructures20260912. No external asset is read.
"""
import sys, math, json, hashlib, argparse
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from geometry_helpers import Geo, mat, make_normals, MATS, MAPS, PALETTE, R
import bpy, bmesh
from mathutils import Vector, Matrix
ROOT=HERE.parents[2]
OUT=ROOT/'game/assets/generated/shopfront_details_20260912'
QA=ROOT/'docs/validation/art_parallel_20260912/shopfront'
TAU=math.tau
ASSETS=[]

def bolt(g,x,y,z,r=.018): g.cyl((x,y,z),(x,y-.012,z),r,'brass',10)
def slab(g,coords,y,depth,role):
    n=len(coords);v=[(x,yy,z) for yy in (y-depth/2,y+depth/2) for x,z in coords]
    f=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    g.mesh(v,f,role)
def frame(g,w,h,z=0,y=-.08,role='oak',rail=.10):
    for x in (-w/2,w/2):g.box((x,y,z+h/2),(rail,.18,h+rail),role)
    for zz in (z,z+h):g.box((0,y,zz),(w+rail,.19,rail),role)
def molding(g,w,z,y=-.10):
    for dz,ww,dd in ((0,w,.23),(.055,w+.12,.28),(.10,w+.06,.22)):
        g.box((0,y,z+dz),(ww,dd,.065),'oak_light')
def strap(g,x,z,y=-.20,w=.20):
    g.box((x,y,z),(w,.025,.052),'iron')
    for xx in (x-w*.32,x+w*.32):bolt(g,xx,y-.02,z,.011)
def round_ring(g,p,inner,outer,role='oak',depth=.13,n=48):
    x,y,z=p
    for i in range(n):
        a=i*TAU/n;b=(i+1)*TAU/n
        slab(g,[(x+inner*math.cos(a),z+inner*math.sin(a)),(x+outer*math.cos(a),z+outer*math.sin(a)),(x+outer*math.cos(b),z+outer*math.sin(b)),(x+inner*math.cos(b),z+inner*math.sin(b))],y,depth,role)
def patterned_grain(g,x0,x1,z0,z1,y,vertical=True):
    # Fine raised short grain strokes, restrained enough for human-scale views.
    for j in range(12):
        x=R.uniform(x0+.02,x1-.02);z=R.uniform(z0+.02,z1-.04)
        if vertical:g.beam((x,y,z),(x+.006,y,z+min(.12,z1-z)),.003,'oak_light')
        else:g.beam((x,y,z),(min(x1,x+.12),y,z+.005),.003,'oak_light')
def display():
    g=Geo();w=2.55;h=1.9
    g.box((0,.07,1.05),(2.50,.10,1.75),'darkwood')
    frame(g,w,h,.17,rail=.16)
    for x in (-1.36,1.36):
        g.box((x,-.11,1.08),(.16,.23,2.06),'oak_light')
        for z in (.18,1.96):g.box((x,-.14,z),(.23,.28,.12),'oak')
        for xx in (x-.045,x+.045):g.box((xx,-.245,1.04),(.014,.018,1.45),'oak')
    molding(g,2.82,2.08);g.box((0,-.20,.08),(2.96,.46,.16),'stone_light')
    for row in range(3):
        for col in range(6):
            x=-1.20+(col+.5)*.4;z=.28+(row+.5)*.56
            g.box((x,-.075,z),(.367,.028,.524),'glass' if (col+row)%3 else 'slate')
    for i in range(1,6):g.box((-1.2+i*.4,-.125,1.13),(.036,.065,1.75),'oak_light')
    for z in (.84,1.40):g.box((0,-.127,z),(2.44,.07,.038),'oak_light')
    for x in (-.95,-.48,0,.48,.95):
        g.box((x,-.253,.19),(.025,.03,.055),'brass')
    return g
def serving():
    g=Geo();frame(g,2.2,1.48,.50,rail=.14)
    g.box((0,.20,1.25),(2.05,.08,1.35),'darkwood')
    for z in (.63,1.22):g.box((0,.04,z),(2.0,.4,.055),'oak_light')
    g.box((0,-.46,.46),(2.42,.97,.115),'oak_light')
    for x in (-.83,.83):
        g.beam((x,-.05,.02),(x,-.86,.38),.067,'iron')
        g.box((x,-.02,.18),(.095,.08,.34),'iron');bolt(g,x,-.071,.22)
    for i in range(9):
        x=-1.05+(i+.5)*2.1/9
        g.box((x,-.45,2.04),(2.1/9-.007,.87,.065),'sage',Matrix.Rotation(math.radians(-10),3,'X'))
    for x in (-.75,.75):
        g.beam((x,-.04,1.52),(x,-.86,2.1),.035,'iron')
        g.cyl((x-.1,-.02,2.01),(x+.1,-.02,2.01),.04,'iron')
    molding(g,2.43,2.04,.025)
    for i in range(7):
        x=-.82+i*.27
        g.lathe((x,-.02,.66),[(.08,0),(.085,.04),(.07,.22),(.035,.26),(.035,.31)],'paper' if i%2 else 'sage',20)
    return g
def diamonds():
    g=Geo();frame(g,1.34,1.91,.16,role='darkwood',rail=.12)
    g.box((0,-.03,1.11),(1.24,.025,1.81),'glass')
    # Clip both diagonal lattice families to the rectangular glazing boundary.
    x0,x1=-.60,.60;z0,z1=.23,2.0
    for slope in (-1,1):
        for c in [i*.29 for i in range(-7,11)]:
            pts=[]
            for x in (x0,x1):
                z=slope*x+c
                if z0<=z<=z1:pts.append((x,-.064,z))
            for z in (z0,z1):
                x=(z-c)/slope
                if x0<=x<=x1:pts.append((x,-.064,z))
            if len(pts)>=2 and (Vector(pts[0])-Vector(pts[1])).length>.001:g.cyl(pts[0],pts[1],.012,'iron',8)
    g.box((0,-.13,1.11),(.052,.05,1.79),'oak_light')
    for z in (.62,1.63):strap(g,-.60,z,w=.12)
    g.box((.13,-.17,1.02),(.10,.032,.03),'brass')
    g.box((0,-.15,.06),(1.64,.47,.12),'stone_light')
    return g
def oculus():
    g=Geo();z=.73
    round_ring(g,(0,-.09,z),.49,.61,'stone_light',.23)
    round_ring(g,(0,-.19,z),.43,.49,'oak',.10)
    g.cyl((0,.015,z),(0,-.025,z),.43,'glass',64)
    for i in range(8):
        a=i*TAU/8;g.beam((.08*math.cos(a),-.095,z+.08*math.sin(a)),(.44*math.cos(a),-.095,z+.44*math.sin(a)),.028,'oak_light')
    round_ring(g,(0,-.11,z),.06,.10,'brass',.05,32)
    for a in (0,math.pi/2,math.pi,3*math.pi/2):
        x=.57*math.cos(a);zz=z+.57*math.sin(a)
        g.box((x,-.235,zz),(.09,.025,.09),'stone')
    return g
def roof_tiles(g,w,depth,eave,rise,cy=-.28):
    for side in (-1,1):
        for y in (cy-depth/2,cy+depth/2):g.beam((0,y,eave+rise),(side*w/2,y,eave),.105,'darkwood')
        for row in range(4):
            t0=row/4;t1=min(1.04,(row+1.18)/4)
            for col in range(5):
                yy=cy-depth/2+(col+.5)*depth/5;tw=depth/5-.009
                shape=[(t0,-tw/2),(t1-.026,-tw/2),(t1,-tw*.34),(t1+.008,0),(t1,tw*.34),(t1-.026,tw/2),(t0,tw/2)]
                v=[(side*(.018+t*w/2),yy+dy,eave+rise*(1-t)+dz+.04+(4-row)*.004) for dz in (0,.028) for t,dy in shape]
                n=7;f=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
                g.mesh(v,f,R.choice(['roof','roof','roof_light','roof_dark']))
        g.beam((side*w/2,cy-depth/2-.04,eave-.02),(side*w/2,cy+depth/2+.04,eave-.02),.13,'oak')
    for i in range(6):
        yy=cy-depth/2+(i+.5)*depth/6
        g.cyl((0,yy-depth/12-.01,eave+rise+.07),(0,yy+depth/12+.01,eave+rise+.07),.073,'roof_dark',16)
def dormer():
    g=Geo()
    # Open-back dormer: cheek walls and framed front, no unwanted wall closure.
    for x in (-.60,.60):
        g.box((x,.04,.62),(.12,.93,1.24),'stone_light')
        g.box((x,-.49,.63),(.13,.12,1.25),'oak')
    slab(g,[(-.62,1.24),(.62,1.24),(0,1.89)],-.43,.13,'stone_light')
    frame(g,.93,.84,.24,-.53,rail=.105)
    g.box((0,-.48,.66),(.83,.024,.74),'glass')
    for x in (-.20,.20):g.box((x,-.565,.66),(.035,.07,.77),'oak_light')
    g.box((0,-.565,.67),(.84,.07,.036),'oak_light')
    g.box((0,-.59,.12),(1.36,.34,.14),'stone')
    g.beam((-.62,-.525,1.23),(0,-.525,1.88),.11,'oak');g.beam((.62,-.525,1.23),(0,-.525,1.88),.11,'oak')
    roof_tiles(g,1.65,1.3,1.18,.84,cy=-.08)
    return g
def chimney():
    g=Geo()
    for row in range(7):
        z=.06+row*.14
        # Open flue with actual interior surfaces; stagger the face joints.
        for side in (-1,1):
            intervals=[(-.36,-.24),(-.24,0),(0,.24),(.24,.36)] if row%2 else [(-.36,-.12),(-.12,.12),(.12,.36)]
            for x0,x1 in intervals:
                g.box(((x0+x1)/2,side*.31,z),(x1-x0-.012,.145,.128),R.choice(['roof','roof_light','roof_dark']))
            for j in range(2):g.box((side*.34,-.155+j*.31,z),(.145,.293,.128),R.choice(['roof','roof_light']))
    for zz,ww,dd in ((1.0,.94,.89),(1.09,1.02,.98)):
        for side in (-1,1):
            g.box((0,side*(dd/2-.09),zz),(ww,.18,.09),'stone_light')
            g.box((side*(ww/2-.09),0,zz),(.18,dd-.30,.09),'stone_light')
    for x in (-.33,.33):
        for y in (-.28,.28):g.box((x,y,1.25),(.105,.10,.28),'stone')
    roof_tiles(g,1.26,.99,1.4,.34,cy=0)
    return g
def rain_eave():
    g=Geo();w=2.65
    g.box((0,-.19,.78),(w,.14,.17),'oak')
    for x in (-1.0,0,1.0):
        g.beam((x,-.015,.15),(x,-.75,.61),.065,'oak')
        g.beam((x,-.03,.75),(x,-.89,.48),.07,'oak_light')
        g.box((x,-.035,.43),(.10,.09,.67),'oak')
        bolt(g,x,-.086,.26)
    for row in range(3):
        for col in range(11):
            x=-w/2+(col+.5)*w/11;y=-.11-row*.245
            r=Matrix.Rotation(math.radians(18),3,'X')
            g.box((x,y,.83+(.11+y)*.32),(w/11-.009,.32,.036),R.choice(['roof','roof','roof_light']),r)
            g.box((x,y-.146,.83+(.11+y)*.32-.052),(w/11-.021,.024,.043),'roof_dark',r)
    g.beam((-w/2,-.82,.57),(w/2,-.82,.57),.10,'oak')
    return g
def corbel():
    g=Geo();g.box((0,-.085,.70),(.19,.16,1.4),'oak')
    g.box((0,-.45,1.30),(.25,.94,.16),'oak_light')
    # Swept carved bracket in Y/Z plane, with a genuine concave profile.
    pts=[(0,-.16,.10),(0,-.22,.22),(0,-.25,.43),(0,-.32,.62),(0,-.43,.78),(0,-.59,.89),(0,-.82,1.00),(0,-.88,1.23)]
    g.tube(pts,.074,'oak',12)
    g.beam((0,-.17,.75),(0,-.74,1.23),.059,'oak_light')
    for z in (.18,.69,1.14):
        g.box((0,-.19,z),(.21,.04,.06),'iron');bolt(g,0,-.22,z,.02)
    for side in (-1,1):
        for j in range(5):
            a=.1+j*.29;g.box((side*.093,-.085,.34+j*.16),(.012,.073,.016),'oak_light')
    return g
def scroll_canopy():
    g=Geo();w=2.52
    # Curved canopy sheet with sewn seams; geometrical thickness, no stripes.
    cols=16;rows=15;v=[]
    for layer in (0,.014):
        for j in range(rows+1):
            t=j/rows;y=-.07-1.13*t;z=1.40-.50*(t*t)+layer
            for i in range(cols+1):v.append((-w/2+w*i/cols,y,z-.018*math.sin(i*math.pi/2)**2))
    f=[];n=(rows+1)*(cols+1)
    for off in (0,n):
        for j in range(rows):
            for i in range(cols):
                a=off+j*(cols+1)+i;f.append((a,a+1,a+cols+2,a+cols+1))
    boundary=list(range(cols+1))+[j*(cols+1)+cols for j in range(1,rows+1)]+[rows*(cols+1)+i for i in range(cols-1,-1,-1)]+[j*(cols+1) for j in range(rows-1,0,-1)]
    for a,b in zip(boundary,boundary[1:]+boundary[:1]):f.append((a,b,b+n,a+n))
    g.mesh(v,f,'cloth')
    for i in range(9):
        x=-w/2+i*w/8
        pts=[(x,-.07-1.13*j/16,1.414-.50*(j/16)**2) for j in range(17)]
        g.tube(pts,.004,'paper',6)
    # Continuous individually scalloped valance, not alternating colour panels.
    for i in range(10):
        x0=-w/2+i*w/10;x1=x0+w/10
        shape=[(x0,.91),(x1,.91)]+[(x1-(x1-x0)*j/8,.78-.065*math.sin(math.pi*j/8)) for j in range(9)]
        slab(g,shape,-1.201,.018,'cloth')
    for x in (-w/2+.06,w/2-.06):
        g.box((x,-.02,1.08),(.08,.075,.73),'iron')
        g.tube([(x,-.08,.80),(x,-.28,.82),(x,-.55,.88),(x,-.78,.99),(x,-1.12,.92)],.028,'iron')
        bolt(g,x,-.068,1.25)
    g.cyl((-w/2-.05,-1.20,.9),(w/2+.05,-1.20,.9),.026,'iron')
    g.cyl((-w/2-.04,-.058,1.42),(w/2+.04,-.058,1.42),.04,'oak')
    return g
def double_portal():
    g=Geo();r=1.02;spring=2.05
    for side in (-1,1):
        for row in range(8):g.box((side*1.15,-.08,.15+row*.255),(.27,.31,.242),'stone_light' if row%3 else 'stone')
        g.box((side*1.15,-.12,.10),(.39,.41,.20),'stone')
        g.box((side*1.15,-.11,2.08),(.39,.39,.14),'stone_light')
    g.arch(0,-.08,spring,r,.27,.31,'stone_light',23,.006)
    # Recessed inner lining and archivolt remain entirely outside passage.
    g.arch(0,-.255,spring,r+.25,.05,.07,'stone',28,.001)
    for side in (-1,1):g.box((side*1.027,-.045,1.08),(.062,.25,1.94),'oak')
    g.arch(0,-.045,spring,.996,.07,.22,'oak',30,.001)
    slab(g,[(-.10,3.07),(.10,3.07),(.14,3.40),(-.14,3.40)],-.15,.42,'stone')
    g.box((0,-.005,.015),(2.12,.43,.03),'stone_dark')
    return g
def glazed_door():
    g=Geo();frame(g,1.18,2.55,.08,role='oak',rail=.13)
    g.box((0,-.054,1.30),(1.03,.12,2.4),'sage')
    for z in (.25,.78):
        g.box((0,-.13,z),(1.0,.075,.10),'oak_light')
    for x in (-.30,.30):
        g.box((x,-.125,.50),(.43,.06,.39),'oak')
        g.box((x,-.165,.50),(.35,.035,.30),'sage')
    g.box((0,-.131,1.66),(.84,.03,1.52),'glass')
    for x in (-.44,0,.44):g.box((x,-.17,1.66),(.042,.055,1.56),'oak_light')
    for z in (.89,1.42,1.94,2.43):g.box((0,-.17,z),(.91,.055,.038),'oak_light')
    for z in (.55,2.04):strap(g,-.42,z,-.218,.17)
    g.box((.41,-.20,1.08),(.06,.025,.22),'iron')
    g.tube([(.405,-.23,1.04),(.40,-.29,1.08),(.29,-.29,1.08)],.018,'brass')
    g.box((0,-.04,.04),(1.43,.37,.08),'stone')
    molding(g,1.42,2.65)
    return g
def niche():
    g=Geo();r=.53;spring=1.35
    g.box((0,.18,.79),(1.20,.12,1.58),'stone_dark')
    slab(g,[(-.6,1.35),(.6,1.35)]+[(.6*math.cos(a),1.35+.6*math.sin(a)) for a in [j*math.pi/20 for j in range(21)]],.18,.12,'stone_dark')
    for side in (-1,1):
        for row in range(5):g.box((side*.65,-.03,.14+row*.255),(.23,.4,.24),'stone_light')
    g.arch(0,-.03,spring,r,.24,.4,'stone_light',17,.005)
    g.box((0,-.20,.08),(1.56,.72,.16),'stone_light')
    g.box((0,-.25,.20),(1.32,.70,.07),'stone')
    # A small botanical relief grows from a real amphora pedestal.
    g.lathe((0,-.02,.26),[(.20,0),(.24,.06),(.20,.14),(.24,.40),(.16,.58),(.12,.62),(.14,.67)],'sage',32)
    for side in (-1,1):g.tube([(side*.13,-.02,.78),(side*.32,-.02,.76),(side*.31,-.02,.58),(side*.22,-.02,.56)],.026,'sage')
    for i in range(5):
        x=(i-2)*.07;top=1.3+.12*math.sin(i)
        g.beam((0,-.02,.89),(x,-.02,top),.018,'oak_light')
        for j in range(3):
            z=1+j*.085
            g.beam((x*.5,-.02,z),(x*.5+.09*(-1 if j%2 else 1),-.02,z+.075),.027,'sage')
    return g
def sign_base(g):
    g.box((0,-.045,.59),(.14,.09,1.14),'iron')
    for z in (.17,.97):bolt(g,0,-.10,z,.023)
    g.beam((0,-.06,.92),(0,-.89,.92),.045,'iron')
    g.beam((0,-.07,.65),(0,-.66,.92),.036,'iron')
def bread_emblem():
    g=Geo();sign_base(g)
    # Pretzel loops and tapered wheat stalks, no generic signboard.
    y=-.83
    for x in (-.17,.17):g.torus((x,y,.49),.21,.05,'oak_light','XZ',40,10)
    g.beam((-.28,y,.32),(.21,y,.69),.085,'oak_light');g.beam((.28,y,.32),(-.21,y,.69),.085,'oak_light')
    for x in (-.33,.33):
        g.beam((x,y,.21),(x*.83,y,.79),.016,'brass')
        for j in range(5):
            zz=.45+j*.065;g.beam((x*.92,y,zz),(x*.92+.055,y,zz+.048),.018,'brass')
    g.cyl((0,y,.61),(0,y,.94),.015,'iron');return g
def apothecary_emblem():
    g=Geo();sign_base(g);y=-.84
    # Mortar silhouette and diagonal pestle, with pierced hanging links.
    slab(g,[(-.34,.56),(.34,.56),(.26,.24),(.15,.17),(-.15,.17),(-.26,.24)],y,.15,'sage')
    g.box((0,y,.57),(.77,.22,.075),'brass');g.box((0,y,.16),(.42,.25,.075),'brass')
    g.beam((-.08,y,.47),(.21,y,.87),.084,'oak_light')
    g.cyl((.18,y,.83),(.25,y,.93),.065,'oak_light',16)
    g.beam((-.30,y,.92),(.30,y,.92),.044,'iron')
    for x in (-.25,.25):g.cyl((x,y,.56),(x,y,.94),.013,'iron')
    return g
def tailor_emblem():
    g=Geo();sign_base(g);y=-.83
    for x in (-.16,.16):g.torus((x,y,.35),.12,.025,'brass','XZ',32,8)
    g.beam((-.10,y,.43),(.24,y,.80),.04,'iron');g.beam((.10,y,.43),(-.24,y,.80),.04,'iron')
    bolt(g,0,y-.035,.55,.036)
    g.cyl((0,y,.55),(0,y,.94),.012,'iron')
    # Needle and eye provide a second recognisable craft cue.
    g.beam((.35,y,.22),(.30,y,.65),.013,'brass');g.torus((.298,y,.68),.035,.01,'brass','XZ',24,6)
    g.tube([(0,y,.55),(.17,y+.015,.62),(.30,y,.715)],.009,'brass',8)
    return g
def barber_emblem():
    g=Geo();sign_base(g);y=-.83
    g.cyl((0,y,.23),(0,y,.78),.13,'paper',32)
    for phase,role in ((0,'roof_light'),(math.pi,'sage')):
        pts=[(.133*math.cos(phase+TAU*2*i/60),y+.133*math.sin(phase+TAU*2*i/60),.25+.50*i/60) for i in range(61)]
        g.tube(pts,.027,role,8)
    for z in (.19,.80):g.lathe((0,y,z),[(.12,0),(.17,.03),(.15,.08)],'brass',32)
    g.cyl((0,y,.89),(0,y,.94),.017,'iron');return g

RECIPES=[
('SF01_Mercer_Display_Window','18-pane mercer display window',display,'wall attachment: lower sill centre, Y=0; requires facade recess'),
('SF02_Folding_Service_Hatch','Open folding service hatch',serving,'wall attachment: bracket foot centre, Y=0; display pose is fixed'),
('SF03_Diamond_Lead_Casement','Diamond lead casement',diamonds,'wall attachment: sill base centre, Y=0'),
('SF04_Radial_Attic_Oculus','Radial attic oculus',oculus,'wall attachment: bounding base, Y=0'),
('SF05_Tiled_Gable_Dormer','Tiled gable dormer',dormer,'roof attachment: base centre, Y=0; roof cutout/placement required'),
('SF06_Open_Flue_Chimney','Open flue chimney with tiled cap',chimney,'roof attachment: base centre; flashing and roof cutout not included'),
('SF07_Clay_Tile_Rain_Eave','Supported clay tile rain eave',rain_eave,'wall attachment: bracket foot, Y=0'),
('SF08_Carved_Timber_Corbel','Carved timber corbel',corbel,'wall attachment: bracket foot, Y=0'),
('SF09_Scalloped_Cloth_Canopy','Curved scalloped cloth canopy',scroll_canopy,'wall attachment: support base, Y=0'),
('SF10_Stone_Double_Portal','Stone arched double portal',double_portal,'ground/door threshold centre, Y=0; clear opening 1.99m width'),
('SF11_Glazed_Shop_Door','Glazed panel shop door',glazed_door,'ground threshold centre, Y=0; closed static visual'),
('SF12_Herbal_Stone_Niche','Herbal amphora stone niche',niche,'wall attachment: sill base centre, Y=0; needs wall recess'),
('SF13_Bakery_Pretzel_Emblem','Bakery pretzel and wheat emblem',bread_emblem,'wall attachment: lower bracket centre, Y=0'),
('SF14_Apothecary_Mortar_Emblem','Apothecary mortar emblem',apothecary_emblem,'wall attachment: lower bracket centre, Y=0'),
('SF15_Tailor_Shears_Emblem','Tailor shears and needle emblem',tailor_emblem,'wall attachment: lower bracket centre, Y=0'),
('SF16_Barber_Spiral_Emblem','Barber spiral pole emblem',barber_emblem,'wall attachment: lower bracket centre, Y=0'),
]

def bounds(ob):
    vs=[ob.matrix_world@v.co for v in ob.data.vertices]
    lo=[min(v[k] for v in vs) for k in range(3)];hi=[max(v[k] for v in vs) for k in range(3)]
    return lo,hi,[hi[k]-lo[k] for k in range(3)]
def point(ob,target): ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
def setup_render():
    sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=28;sc.cycles.use_denoising=True
    sc.render.resolution_x=2000;sc.render.resolution_y=1900;sc.render.resolution_percentage=100
    sc.world.color=(.35,.35,.35)
    world=sc.world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.52,.58,.63,1);world.node_tree.nodes['Background'].inputs[1].default_value=.45
    sc.view_settings.view_transform='AgX';sc.view_settings.look='AgX - Medium High Contrast'
    col=bpy.data.collections.new('PRESENTATION_NOT_EXPORTED');sc.collection.children.link(col)
    for name,loc,power,size in [('Key',(-9,-11,20),2200,10),('Fill',(10,-5,12),1500,9),('Top',(0,3,18),1700,7)]:
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size
        ob=bpy.data.objects.new(name,d);col.objects.link(ob);ob.location=loc;point(ob,(0,0,5))
    data=bpy.data.cameras.new('CatalogueCamera');cam=bpy.data.objects.new('CatalogueCamera',data);col.objects.link(cam)
    cam.location=(8,-32,17);point(cam,(0,0,6.1));data.type='ORTHO';data.ortho_scale=17.6;sc.camera=cam
    return col,cam
def text_label(col,label,x,z,size=.14):
    cu=bpy.data.curves.new('CatalogueLabel','FONT');cu.body=label;cu.size=size;cu.align_x='CENTER';cu.extrude=.0003
    ob=bpy.data.objects.new(label,cu);col.objects.link(ob);ob.location=(x,-.04,z);ob.rotation_euler=(math.pi/2,0,0);cu.materials.append(mat('darkwood'))
def validate_glbs():
    # True glTF re-import, independent of the pre-export mesh counts.
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    results=[]
    for path in sorted(OUT.glob('SF*.glb')):
        bpy.ops.import_scene.gltf(filepath=str(path));meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
        bad_coord=bad_norm=bad_uv=bad_tri=bad_mat=0;zero_derived_normals=0;tris=0;verts=0;lo=[1e9]*3;hi=[-1e9]*3
        for ob in meshes:
            me=ob.data;me.calc_loop_triangles();verts+=len(me.vertices);tris+=len(me.loop_triangles)
            for v in me.vertices:
                co=ob.matrix_world@v.co
                if not all(math.isfinite(x) for x in co):bad_coord+=1
                for k in range(3):lo[k]=min(lo[k],co[k]);hi[k]=max(hi[k],co[k])
                # glTF NORMAL is a split corner attribute. Blender's derived
                # vertex average can cancel even when imported shading normals
                # are valid; inspect the actual corner normals below.
                if not all(math.isfinite(x) for x in v.normal):bad_norm+=1
                if v.normal.length<.5:zero_derived_normals+=1
            for normal in me.corner_normals:
                if not all(math.isfinite(x) for x in normal.vector) or abs(normal.vector.length-1)>.01:bad_norm+=1
            if not me.uv_layers:bad_uv+=1
            else:
                for uv in me.uv_layers[0].data:
                    if not all(math.isfinite(x) for x in uv.uv):bad_uv+=1
            for t in me.loop_triangles:
                a,b,c=[me.vertices[i].co for i in t.vertices]
                if (b-a).cross(c-a).length/2<1e-10:bad_tri+=1
                if t.material_index>=len(me.materials) or me.materials[t.material_index] is None:bad_mat+=1
        errors={'nonfinite_positions':bad_coord,'invalid_normals':bad_norm,'missing_or_nonfinite_uvs':bad_uv,'degenerate_triangles':bad_tri,'invalid_material_assignments':bad_mat}
        results.append({'file':path.name,'triangles':tris,'vertices':verts,'dimensions_xyz_m':[round(hi[k]-lo[k],5) for k in range(3)],'zero_derived_vertex_averages_not_shading_normals':zero_derived_normals,'errors':errors,'pass':not any(errors.values())})
        bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    report={'method':'Blender native glTF importer on every actual exported GLB; finite positions/normals/UVs, triangle area and material assignment checks','count':len(results),'passed':all(r['pass'] for r in results),'assets':results}
    (QA/'glb_roundtrip_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('ROUNDTRIP_VALIDATION',report['passed'],len(results),flush=True)
    if not report['passed']:raise RuntimeError('Roundtrip validation failed; inspect report')
def build(no_render=False):
    for path in (OUT,QA,HERE/'textures'):path.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    make_normals();sc=bpy.context.scene;sc.unit_settings.system='METRIC';sc.unit_settings.scale_length=1
    for idx,(name,title,fn,origin) in enumerate(RECIPES):
        col=bpy.data.collections.new(name);sc.collection.children.link(col)
        ob=fn().object(name,col)
        # All attachment bases are normalized consistently without changing wall plane.
        zmin=min(v.co.z for v in ob.data.vertices)
        for v in ob.data.vertices:v.co.z-=zmin
        ob['origin_semantics']=origin;ob['title']=title
        bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
        path=OUT/(name+'.glb')
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_apply=True,export_texcoords=True,export_normals=True,export_tangents=True,export_materials='EXPORT',export_yup=True)
        lo,hi,dims=bounds(ob);ob.data.calc_loop_triangles()
        ASSETS.append({'id':name,'title':title,'file':str(path.relative_to(ROOT)).replace('\\','/'),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size,'dimensions_xyz_m':[round(v,5) for v in dims],'bounds_xyz_m':[lo,hi],'triangles':len(ob.data.loop_triangles),'materials':[m.name for m in ob.data.materials],'origin':origin,'source':'Original procedural geometry in build_shopfront_details.py; local minimal helper adapted from StreetStructures20260912; all texture maps generated from seeded arithmetic','runtime_scope':'static visual attachment; no interaction, collision, animation, navigation, LOD or world-state integration'})
        x=((idx%4)-1.5)*3.7;z=(3-idx//4)*3.7
        ob.location=(x,0,z)
        print('EXPORTED',name,len(ob.data.loop_triangles),flush=True)
    (HERE/'manifest.json').write_text(json.dumps({'units':'metres','source_axes':'Blender X right, -Y front, Z up; standard glTF Y-up conversion','authorship':'2026-09-12 GPT-6 Astra authorized parallel art task','external_inputs':[],'asset_count':len(ASSETS),'assets':ASSETS},indent=2),encoding='utf-8')
    (OUT/'manifest.json').write_bytes((HERE/'manifest.json').read_bytes())
    col,cam=setup_render()
    for idx,entry in enumerate(ASSETS):
        x=((idx%4)-1.5)*3.7;z=(3-idx//4)*3.7
        panel=Geo();panel.box((x,.86,z+1.60),(3.51,.08,3.62),'stone_light');panel.object('DisplayPanel_'+str(idx+1),col)
        text_label(col,entry['id'][:4]+' / '+entry['title'],x,z-.17,.108)
    text_label(col,'STARTING TOWN / SHOPFRONT DETAILS',0,14.71,.32)
    text_label(col,'16 original metric facade attachments | static visual kit',0,14.32,.17)
    cam.location=(6,-36,16);point(cam,(0,0,7.1));cam.data.ortho_scale=17.5
    sc.render.filepath=str(QA/'overview.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'ShopfrontDetails20260912.blend'))
    if not no_render:
        bpy.ops.render.render(write_still=True)
        sc.render.resolution_x=1500;sc.render.resolution_y=1250
        for indexes,name in [([0,1],'detail_windows'),([4,5],'detail_roofwork'),([8,9],'detail_canopy_portal'),([12,13,14,15],'detail_craft_emblems')]:
            # Select one row pair/group; hide all other panels and labels as well.
            visible_ids={RECIPES[i][0] for i in indexes}
            for ob in sc.objects:
                if ob.type in ('MESH','FONT'):ob.hide_render=True
            for i in indexes:
                ob=bpy.data.objects[RECIPES[i][0]];ob.hide_render=False
                bpy.data.objects['DisplayPanel_'+str(i+1)].hide_render=False
            a=bpy.data.objects[RECIPES[indexes[0]][0]].location;b=bpy.data.objects[RECIPES[indexes[-1]][0]].location
            mid=(a+b)/2+Vector((0,0,1.45));cam.location=mid+Vector((2.1,-15,3.3));point(cam,mid)
            cam.data.ortho_scale=8 if len(indexes)==2 else 15.5
            sc.render.filepath=str(QA/(name+'.png'));bpy.ops.render.render(write_still=True)
        for ob in sc.objects:ob.hide_render=False
    validate_glbs()

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--no-render',action='store_true');parser.add_argument('--validate-only',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    if args.validate_only:validate_glbs()
    else:build(args.no_render)
