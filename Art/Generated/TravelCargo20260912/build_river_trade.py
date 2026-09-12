"""Twelve original river/trail props; run after build_travel_cargo.py.

Keeps an independent Blender library and merges both source manifests by ID.
No third-party art or private world state is read.
"""
import sys, math, json, hashlib, os, time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import bpy
from mathutils import Vector, Matrix
import build_travel_cargo as base
from geometry import Geo, material, plank, pot
HERE=base.HERE;ROOT=base.ROOT;OUT=base.OUT;EVIDENCE=base.EVIDENCE
TAU=math.tau

def boat():
    g=Geo()
    # Open double-skin lapstrake hull with a narrow keel, three benches and ribs.
    sections=[(-1.65,.025,.60),(-1.4,.32,.48),(-.95,.54,.39),(0,.64,.36),(.95,.54,.39),(1.4,.32,.48),(1.65,.025,.6)]
    for side in (-1,1):
        for layer in range(5):
            t0=layer/5;t1=(layer+1)/5;v=[]
            for y,w,lip in sections:
                for t in (t0,t1):v.append((side*w*math.sin(t*math.pi/2),y,.07+(lip-.07)*t))
            f=[(2*j,2*j+1,2*j+3,2*j+2) for j in range(len(sections)-1)]
            # Wood thickness extends inward from both sides.
            n=len(v);inner=[(x-side*.028,y,z+.008) for x,y,z in v]
            faces=f+[tuple(i+n for i in reversed(face)) for face in f]
            faces += [(2*j+1,2*j+3,2*j+3+n,2*j+1+n) for j in range(len(sections)-1)]
            faces += [(2*j,2*j+n,2*j+2+n,2*j+2) for j in range(len(sections)-1)]
            faces += [(0,1,1+n,n),(n-2,2*n-2,2*n-1,n-1)]
            g.mesh(v+inner,faces,'oak_light' if layer%2 else 'oak')
        g.tube([(side*w,y,lip+.013) for y,w,lip in sections],.036,'oak_dark',10)
    g.tube([(0,y,.035+(.23 if abs(y)>1.5 else 0)) for y,_,_ in sections],.045,'oak_dark',10)
    for y,w in ((-.87,.47),(0,.59),(.87,.47)):
        plank(g,(0,y,.35),(w*2,.25,.06),'oak_light')
        g.tube([(-w,y,.34),(-w*.7,y,.17),(0,y,.10),(w*.7,y,.17),(w,y,.34)],.028,'oak_dark',8)
    for x in (-.61,.61):g.ring((x,-.25,.4),.055,.014,'iron','Y',24)
    for y in (-1.64,1.64):g.ring((0,y,.65),.055,.014,'iron','Y',24)
    return g

def oars():
    g=Geo()
    for x in (-.22,.22):
        g.rod((x,0,.04),(x,1.55,.04),.024,'oak_light',14)
        # Tapered blade with true thickness and bevels.
        g.box((x,-.23,.04),(.19,.59,.049),'oak_light',.02)
        g.box((x,-.47,.04),(.21,.045,.056),'oak_dark',.009)
        for y in (.96,1.02,1.08,1.14):g.ring((x,y,.04),.027,.007,'leather','Y',16,6)
    return g

def anchor():
    g=Geo();g.rod((0,0,.07),(0,0,.89),.045,'iron',12)
    g.ring((0,0,1.02),.1,.025,'iron','Y',32)
    g.box((0,0,.74),(.74,.12,.11),'oak',.025)
    for side in (-1,1):
        g.tube([(0,0,.1),(side*.18,0,.06),(side*.35,0,.17),(side*.41,0,.32)],.04,'iron',10)
        base.cloth_panel(g,[(side*.29,-.035,.24),(side*.46,-.035,.4),(side*.44,-.035,.2)],'iron',.07)
        g.box((side*.28,0,.74),(.045,.14,.13),'iron',.01)
    return g

def fish_trap():
    g=Geo()
    # Horizontal wicker cylinder with funnel opening rather than a solid barrel.
    for j in range(11):g.ring((0,-.43+j*.086,.27),.26,.012,'oak_light','Y',40,6)
    for j in range(24):
        a=TAU*j/24;x=.26*math.cos(a);z=.27+.26*math.sin(a)
        g.tube([(x,-.45,z),(x,.43,z)],.011,'oak',6)
        g.tube([(x,-.45,z),(x*.28,-.16,.27+(z-.27)*.28)],.008,'oak',6)
    g.ring((0,-.16,.27),.074,.012,'oak_dark','Y',28,6)
    for j in range(8):
        t=-.22+j*.44/7;h=math.sqrt(.26**2-t*t)
        g.rod((-h,.44,.27+t),(h,.44,.27+t),.01,'oak',6)
    g.tube([(0,.42,.51),(.04,.56,.6),(.2,.58,.58)],.01,'rope',6)
    return g

def fishing_net():
    g=Geo()
    for x in (-.8,.8):
        g.rod((x,0,0),(x,0,1.7),.032,'oak',12)
        g.box((x,0,.025),(.1,.5,.05),'oak_dark')
    g.rod((-.82,0,1.61),(.82,0,1.61),.032,'oak_light',12)
    # Diamond net fully open to light, attached at both ends.
    for j in range(-10,11):
        pts=[]
        for k in range(41):
            z=.15+1.43*k/40;x=j*.15+(z-.15)*.6
            if -.77<=x<=.77:pts.append((x,-.018-.045*math.sin((x+.77)*math.pi/1.54),z))
        if len(pts)>1:g.tube(pts,.0045,'rope',5)
        pts=[]
        for k in range(41):
            z=.15+1.43*k/40;x=j*.15-(z-.15)*.6
            if -.77<=x<=.77:pts.append((x,-.018-.045*math.sin((x+.77)*math.pi/1.54),z))
        if len(pts)>1:g.tube(pts,.0045,'rope',5)
    for x in (-.76,.76):g.rod((x,-.018,.15),(x,-.018,1.6),.01,'rope',6)
    return g

def buoy():
    g=Geo();g.lathe((0,0,.02),[(.07,0),(.19,.14),(.23,.28),(.18,.42),(.06,.51)],'oak_light',24)
    for z,r in ((.14,.19),(.3,.225),(.42,.18)):g.ring((0,0,z),r,.024,'rust_cloth','Z',32)
    g.rod((0,0,.43),(0,0,1.15),.022,'oak_dark',12)
    base.cloth_panel(g,[(0,0,1.13),(.31,0,1.04),(.29,0,.86),(0,0,.94)],'sage')
    g.tube([(0,0,.04),(.26,0,.025),(.35,-.11,.025),(.2,-.25,.025),(.06,-.22,.025)],.012,'rope',6)
    return g

def rolled_sail():
    g=Geo()
    g.cyl((-.85,0,.22),.18,1.7,'canvas',32,Matrix.Rotation(math.pi/2,3,'Y'))
    g.rod((-1.04,-.13,.11),(1.04,-.13,.11),.042,'oak_light',14)
    for x in (-.57,0,.57):g.ring((x,0,.22),.19,.018,'rope','X',32)
    for x in (-.85,.85):
        for r in (.06,.12):g.ring((x,0,.22),r,.007,'canvas_dark','X',28,6)
    return g

def hammock():
    g=Geo()
    for side in (-1,1):
        g.beam((side*1.42,0,.02),(side*1.2,0,1.03),.09,'oak')
        g.box((side*1.42,0,.055),(.21,1.0,.11),'oak_dark')
    g.box((0,0,.12),(2.88,.11,.12),'oak')
    for j in range(24):
        x=-1+j/12;xx=x+1/12
        z=.39+.44*x*x;zz=.39+.44*xx*xx
        base.cloth_panel(g,[(x,-.39,z),(xx,-.39,zz),(xx,.39,zz),(x,.39,z)],'canvas' if j%5 else 'sage')
    for side in (-1,1):
        g.rod((side, -.4,.84),(side,.4,.84),.025,'oak_light',12)
        for y in (-.38,-.19,0,.19,.38):g.rod((side,y,.84),(side*1.2,0,1.03),.007,'rope',6)
    return g

def gangplank():
    g=Geo()
    for x in (-.31,.31):g.beam((x,-1.2,.07),(x,1.2,.28),.1,'oak_dark')
    for j in range(13):
        y=-1.13+j*2.26/12;z=.18+y*.21/2.4
        plank(g,(0,y,z),(.89,.175,.07),'oak_light')
        if j%3==0:g.box((0,y,z+.044),(.85,.04,.022),'oak_dark',.005)
    for y in (-1.0,1.0):
        z=.18+y*.21/2.4
        for x in (-.43,.43):g.rod((x,y,z),(x,y,z+.73),.025,'iron',12)
    for x in (-.43,.43):g.tube([(x,-1,.82),(x,0,.77),(x,1,1.0)],.014,'rope',8)
    return g

def walking_sticks():
    g=Geo()
    g.box((0,0,.075),(.63,.37,.15),'oak_dark',.025)
    for j in range(5):
        x=-.23+j*.115;h=1.21+j*.055
        g.tube([(x,0,.08),(x+.012,0,h*.48),(x-.012,0,h*.8),(x,0,h),(x+.04,0,h+.05),(x+.07,0,h+.02)],.018,'oak_light' if j%2 else 'oak',10)
        g.ring((x,0,.15),.021,.006,'iron','Z',16,6)
        for z in (h-.05,h-.09,h-.13):g.ring((x,0,z),.021,.006,'leather','Z',16,6)
    for x in (-.29,.29):g.rod((x,.09,.12),(x,.09,.65),.022,'oak',10)
    g.rod((-.29,.09,.62),(.29,.09,.62),.022,'oak_dark',10)
    return g

def courier_cage():
    g=Geo();g.box((0,0,.04),(.64,.43,.08),'oak_light',.02)
    for y in (-.2,.2):
        for j in range(9):
            x=-.3+j*.075;top=.43+.17*math.sqrt(max(0,1-(x/.3)**2))
            g.rod((x,y,.06),(x,y,top),.007,'iron',8)
        g.tube([(.3*math.cos(math.pi*k/28),y,.43+.17*math.sin(math.pi*k/28)) for k in range(29)],.022,'oak',8)
        g.box((0,y,.28),(.64,.024,.037),'oak_dark')
    for j in range(7):
        y=-.2+j*.4/6
        g.tube([(.3*math.cos(math.pi*k/28),y,.43+.17*math.sin(math.pi*k/28)) for k in range(29)],.007,'iron',8)
    for x in (-.3,.3):
        for y in (-.1,0,.1):g.rod((x,y,.06),(x,y,.43),.007,'iron',8)
    g.rod((-.29,.02,.23),(.29,.02,.23),.017,'oak_light',12)
    pot(g,(-.17,-.08,.08),.047,.062,'terracotta')
    g.ring((0,0,.69),.08,.016,'leather','Y',28)
    return g

def map_table():
    g=Geo()
    for y in (-.31,.31):
        g.beam((-.47,y,.02),(.38,y,.86),.055,'oak')
        g.beam((.47,y,.02),(-.38,y,.86),.055,'oak_light')
        g.rod((0,y-.035,.49),(0,y+.035,.49),.033,'brass',12)
    for j in range(6):plank(g,(-.45+j*.18,0,.88),(.172,.82,.065),'oak_light')
    g.box((0,0,.918),(.79,.56,.009),'paper',.01)
    for offset in (-.12,.08):g.tube([(-.32+j*.08,offset+.09*math.sin(j*1.05),.925) for j in range(9)],.003,'sage',6)
    for x,y in ((-.26,-.1),(.21,.14),(.12,-.14)):
        g.ring((x,y,.928),.025,.004,'ink','Z',18,6)
    g.lathe((.37,.29,.918),[(.06,0),(.062,.025),(.05,.035)],'brass',28)
    g.rod((.37,.255,.958),(.37,.325,.958),.007,'iron',8)
    return g

ASSETS=[('lapstrake_river_rowboat','搭接木板河舟',boat),('paired_wooden_oars','双支木桨',oars),
 ('wood_stock_river_anchor','木横杆河锚',anchor),('woven_funnel_fish_trap','漏斗口编织鱼笼',fish_trap),
 ('diamond_fishing_net_frame','菱格渔网晾架',fishing_net),('flagged_wooden_fishing_buoy','木浮标与布旗',buoy),
 ('furled_canvas_sail','卷帆与桁杆',rolled_sail),('timber_frame_hammock','木架悬吊布床',hammock),
 ('roped_ferry_gangplank','扶绳渡船跳板',gangplank),('trail_walking_stick_rack','旅行手杖架',walking_sticks),
 ('empty_courier_bird_cage','空信鸟运输笼',courier_cage),('folding_route_map_table','折叠路线图桌',map_table)]

def main():
    started=time.time();bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    s=bpy.context.scene;s.unit_settings.system='METRIC';s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=True
    s.render.threads_mode='FIXED';s.render.threads=2;s.view_settings.view_transform='AgX';s.world.color=(.28,.28,.28)
    s.render.resolution_x=1900;s.render.resolution_y=1300;s.render.resolution_percentage=100
    items=[];sources=[]
    for i,(key,label,fn) in enumerate(ASSETS):
        col=bpy.data.collections.new('TC_'+key);s.collection.children.link(col);obj=fn().finish('TC_'+key,col);base.clean_mesh(obj)
        low=min(v.co.z for v in obj.data.vertices)
        for v in obj.data.vertices:v.co.z-=low
        vs=[v.co for v in obj.data.vertices];obj.data.calc_loop_triangles()
        lo=[min(v[a] for v in vs) for a in range(3)];hi=[max(v[a] for v in vs) for a in range(3)]
        assert all(math.isfinite(n) for v in vs for n in v)
        obj.asset_mark();obj.asset_data.description=label+' | original river/trail prop'
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
        p=OUT/(key+'.glb');bpy.ops.export_scene.gltf(filepath=str(p),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_cameras=False,export_lights=False);obj.select_set(False)
        items.append({'id':key,'label_zh':label,'file':p.relative_to(ROOT).as_posix(),'triangles':len(obj.data.loop_triangles),'vertices':len(vs),
          'dimensions_m':[round(hi[a]-lo[a],5) for a in range(3)],'bounds_min_m':lo,'bounds_max_m':hi,'ground_origin':True,
          'materials':[m.name for m in obj.data.materials],'material_count':len(obj.data.materials),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size})
        obj.location=((i%4)*4,(i//4)*4,0);sources.append(obj);print('ASSET_COMPLETE',key,flush=True)
    manifest={'pack':'river_trade_supplement','asset_count':len(items),'assets':items,'units':'metres','scope':'Original decorative assets; no functional boats, navigation, fishing, or animals.'}
    (HERE/'river_trade_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    combined=json.loads((HERE/'manifest.json').read_text(encoding='utf-8'));by_id={x['id']:x for x in combined['assets']}
    by_id.update({x['id']:x for x in items});combined['assets']=list(by_id.values());combined['asset_count']=len(by_id);combined['total_triangles']=sum(x['triangles'] for x in by_id.values())
    combined['source_libraries']=['Art/Generated/TravelCargo20260912/travel_cargo_library.blend','Art/Generated/TravelCargo20260912/river_trade_library.blend']
    for p in (HERE/'manifest.json',OUT/'manifest.json',EVIDENCE/'manifest.json'):p.write_text(json.dumps(combined,ensure_ascii=False,indent=2),encoding='utf-8')
    for obj in sources:obj.hide_render=True;obj.hide_set(True)
    col=bpy.data.collections.new('PRESENTATION_ONLY');s.collection.children.link(col);display=[]
    for i,source in enumerate(sources):
        ob=bpy.data.objects.new('DISPLAY_'+source.name,source.data);col.objects.link(ob);sc=2.55/max(items[i]['dimensions_m']);ob.scale=(sc,)*3;ob.location=((i%4)*3.45,(2-i//4)*3.65,0);display.append(ob)
        font=bpy.data.curves.new('Label','FONT');font.body='%02d %s'%(i+25,ASSETS[i][0].replace('_',' '));font.size=.14;font.align_x='CENTER';font.materials.append(material('ink'))
        lab=bpy.data.objects.new('Label',font);col.objects.link(lab);lab.location=(ob.location.x,ob.location.y-1.3,.006)
    ground=Geo();ground.box((5.2,3.6,-.09),(15.3,12.6,.16),'canvas',.04);floor=ground.finish('PresentationFloor',col)
    cam=base.camera((18,-23,28),(5.2,3.6,.6),18.5)
    lights=[base.area('Key',(1,-5,14),2400,9,(5,3,0)),base.area('Fill',(13,8,11),1800,8,(5,3,0))]
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'river_trade_library.blend'))
    s.render.filepath=str(EVIDENCE/'river_trade_contact_sheet.png');bpy.ops.render.render(write_still=True)
    for ob in col.objects:ob.hide_render=True
    floor.hide_render=False;floor.location=(-5.2,-3.6,0)
    for i,p in zip([0,1,2,3,4,5,8],[(0,0,0),(1.4,0,0),(-1.25,-1.35,0),(-1.8,.35,0),(-1.4,1.8,0),(1.3,1.1,0),(2.8,.1,0)]):display[i].hide_render=False;display[i].location=p;display[i].scale=(1,1,1)
    cam.location=(9,-12,10);cam.rotation_euler=(Vector((.4,.2,.7))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=7.8
    s.render.resolution_x=1800;s.render.resolution_y=1350;s.cycles.samples=32
    s.render.filepath=str(EVIDENCE/'river_trade_detail.png');bpy.ops.render.render(write_still=True)
    (EVIDENCE/'river_run_complete.json').write_text(json.dumps({'pid':os.getpid(),'assets':len(items),'seconds':time.time()-started}),encoding='utf-8')
    print('RIVER_TRADE_COMPLETE',len(items),flush=True)

if __name__=='__main__':main()
