"""Author deterministic food-city frontage, plazas and a shared ground atlas.

No imported game art. The runtime and QA read the same route/plot plan.
"""
from pathlib import Path
import json
import heapq
import math
import random
import re
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/food_city'
EVIDENCE = ROOT / 'artifacts/world-expansion-20260929/atlas'
RNG = random.Random(2026092804)
BOUNDS_SOURCE = (ROOT / 'fidelity/world_bounds.gd').read_text()
WORLD_HALF = float(re.search(r'const HALF\s*:=\s*([\d.]+)', BOUNDS_SOURCE).group(1))
PLAY_LIMIT = float(re.search(r'const PLAY_LIMIT\s*:=\s*([\d.]+)', BOUNDS_SOURCE).group(1))
def distance(a, b): return math.hypot(a[0]-b[0], a[1]-b[1])
def mix(a,b,t): return (a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t)


def closest(p, points):
    best = (1e10,None,None)
    for a,b in zip(points,points[1:]):
        dx,dz=b[0]-a[0],b[1]-a[1]
        t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz)))
        q=mix(a,b,t);d=distance(p,q)
        if d<best[0]: best=(d,q,math.atan2(dx,dz))
    return best


def spline(points):
    result=[];ps=[points[0],*points,points[-1]]
    for i in range(1,len(ps)-2):
        a,b,c,d=ps[i-1:i+3]
        for j in range(8):
            t=j/8
            result.append(tuple(.5*((2*b[k])+(-a[k]+c[k])*t+(2*a[k]-5*b[k]+4*c[k]-d[k])*t*t+(-a[k]+3*b[k]-3*c[k]+d[k])*t*t*t) for k in range(2)))
    return [*result,points[-1]]


def resample(points, step=1.0):
    result=[points[0]];along=0;next_sample=step
    for a,b in zip(points,points[1:]):
        length=distance(a,b)
        while next_sample<along+length:
            result.append(mix(a,b,(next_sample-along)/length));next_sample+=step
        along+=length
    result.append(points[-1]);return result


class Corridors:
    """Bounded segment queries keep deterministic placement inexpensive."""
    def __init__(self, routes):
        self.bins={}
        for route in routes:
            for a,b in zip(route['points'],route['points'][1:]):
                w=route['half_width']
                for x in range(math.floor((min(a[0],b[0])-w)/8),math.floor((max(a[0],b[0])+w)/8)+1):
                    for z in range(math.floor((min(a[1],b[1])-w)/8),math.floor((max(a[1],b[1])+w)/8)+1):
                        self.bins.setdefault((x,z),[]).append((a,b,w))
    def hits(self,p,margin):
        for x in range(math.floor((p[0]-margin)/8),math.floor((p[0]+margin)/8)+1):
            for z in range(math.floor((p[1]-margin)/8),math.floor((p[1]+margin)/8)+1):
                for a,b,w in self.bins.get((x,z),[]):
                    if closest(p,[a,b])[0]<w+margin:return True
        return False


def polygon_for(center, centers):
    polygon=[(-70,-68),(70,-68),(70,69),(-70,69)]
    for other in centers:
        if other==center:continue
        nx,nz=other[0]-center[0],other[1]-center[1]
        c=(other[0]**2+other[1]**2-center[0]**2-center[1]**2)/2
        clipped=[]
        for a,b in zip(polygon,polygon[1:]+polygon[:1]):
            da=a[0]*nx+a[1]*nz-c;db=b[0]*nx+b[1]*nz-c
            if da<=0:clipped.append(a)
            if (da<0)!=(db<0):clipped.append(mix(a,b,da/(da-db)))
        polygon=clipped
    return polygon


def make_plan():
    RNG.seed(2026092804)
    # One continuous boulevard, with an oblique cross-town street and T branches.
    # Nodes are actual shared junctions, not disconnected decorative curves.
    ring=[(-51,51),(-59,8),(-43,-30),(-15,-50),(20,-51),(49,-28),
          (56,10),(38,47),(8,60),(-24,52)]
    nodes=[{'at':p} for p in ring]+[{'at':(-18,4)},{'at':(21,-13)}]
    roads=[];traffic=[]
    # Periodic Catmull-Rom: lane position and tangent stay continuous at the seam.
    for i in range(len(ring)):
        a,b,c,d=[ring[j%len(ring)] for j in (i-1,i,i+1,i+2)]
        ps=[]
        for j in range(25):
            t=j/24
            ps.append(tuple(.5*((2*b[k])+(-a[k]+c[k])*t+(2*a[k]-5*b[k]+4*c[k]-d[k])*t*t+(-a[k]+3*b[k]-3*c[k]+d[k])*t*t*t) for k in range(2)))
        roads.append({'name':'Grand Glaze %02d'%i,'from':i,'to':(i+1)%10,'points':ps,'half_width':3.25,'class':'boulevard'})
        traffic.extend(ps[:-1])
    traffic.append(traffic[0])
    for name,start,end,bends in [
        ('Biscuit Approach',1,10,[(-45,12),(-31,9)]),
        ('Market Diagonal',10,11,[(-5,-1),(8,-6)]),
        ('Harbor High Street',11,5,[(35,-23)]),
        ('Frosting Rise',10,3,[(-24,-14),(-20,-34)]),
        ('Sundae Avenue',11,7,[(28,7),(25,29)])]:
        roads.append({'name':name,'from':start,'to':end,'points':resample(spline([nodes[start]['at'],*bends,nodes[end]['at']]),1.0),
                      'half_width':2.7,'class':'high_street'})
    # One closed delivery route visits every branch, including the market
    # diagonal in both directions, joined by actual boulevard segments.
    inner=[]
    circuit=[1,10,11,5,6,7,11,10,3,2,1]
    for start,end in zip(circuit,circuit[1:]):
        edge=next(e for e in roads if {e['from'],e['to']}=={start,end})
        points=edge['points'] if edge['from']==start else list(reversed(edge['points']))
        inner.extend(points[:-1])
    inner.append(inner[0])
    road_space=Corridors(roads)
    routes=[]
    # Sidewalks inherit the road geometry and stop before road junctions. They
    # never send pedestrians across live lanes without a crossing controller.
    for edge,road in enumerate(roads):
        ps=resample(road['points'],.8)
        for side in [-1,1]:
            runs=[];run=[]
            for i,p in enumerate(ps):
                a=ps[max(0,i-1)];b=ps[min(len(ps)-1,i+1)];length=distance(a,b)
                offset=road['half_width']+1.85
                q=(p[0]-(b[1]-a[1])/length*offset*side,p[1]+(b[0]-a[0])/length*offset*side)
                if not road_space.hits(q,1.4):run.append(q)
                else:
                    if len(run)>10:runs.append(run)
                    run=[]
            if len(run)>10:runs.append(run)
            for run in runs:
                routes.append({'name':road['name']+(' West Walk' if side<0 else ' East Walk'),'points':run,'half_width':1.05,'road':edge})
    # A recognizable market, connected by narrow alleys rather than a grid cell.
    market=[(1+9.1*math.cos(i*math.tau/48),23+7.7*math.sin(i*math.tau/48)) for i in range(49)]
    routes.append({'name':'Crescent Market','points':market,'half_width':1.05,'road':-1})
    for name,points in [('Market North',[(1,15.3),(-3,10),(-8,6)]),
                        ('Market West',[(-8.1,23),(-17,24),(-28,30),(-39,37)]),
                        ('Market South',[(1,30.7),(2,39),(7,45),(9,52)]),
                        ('Harbor Lane',[(10.1,23),(15,19),(20,12)])]:
        routes.append({'name':name,'points':resample(spline(points)), 'half_width':.95,'road':-1})
    walking_space=Corridors(routes)
    centers=[(-47,-42),(-5,-31),(42,-34),(-44,11),(1,26),(47,32),(-30,52)]
    names=['Berry Quay','Frosting Heights','Wafer Harbor','Biscuit Old Town','Crescent Market','Sundae Terrace','Pastry Gardens']
    districts=[{'name':name,'center':p,'polygon':polygon_for(p,centers)} for name,p in zip(names,centers)]
    def district_at(p):return min(range(len(centers)),key=lambda i:distance(p,centers[i]))
    def clear(p,radius):
        return (max(abs(p[0]),abs(p[1]))<69-radius and not road_space.hits(p,radius+.3)
                and not walking_space.hits(p,radius+.3) and distance(p,(1,23))>11+radius)
    starters=[{'at':p,'radius':1.8,'yaw':0,'starter':True} for p in [(-2.7,19.6),(4,22.7),(.4,27)]]
    heaps=[]
    # Reserve markets before infill, so their real rotated envelopes stay clear.
    for attempt in range(20000):
        if len(heaps)>=12:break
        p=(RNG.uniform(-64,64),RNG.uniform(-62,63));i=district_at(p);r=3.7
        if sum(h['district']==i for h in heaps)>=2:continue
        if not clear(p,r) or any(distance(p,h['at'])<r+h['radius']+2 for h in heaps):continue
        heaps.append({'at':p,'radius':r,'yaw':RNG.uniform(-1.2,1.2),'district':i})
    plots=[];candidates=[]
    # Small inward-market frontages sit beside the first cascades rather than
    # leaving an eleven-metre building-free court. Their reserved envelopes
    # clear the actual curved walk and all three starter heaps.
    for at,kind,family in [((3.0,18.5),'cake','cakery'),((-4.0,23.0),'burger','diner')]:
        ri=min(range(len(routes)),key=lambda j:closest(at,routes[j]['points'])[0]);_,q,_=closest(at,routes[ri]['points'])
        plots.append({'at':at,'size':.85,'radius':1.25,'yaw':math.atan2(q[0]-at[0],q[1]-at[1]),
                      'kind':kind,'family':family,'floors':2,'flavor':0,'district':4,'route':ri,'role':'shop','opening':True})
    for ri,route in enumerate(routes):
        ps=resample(route['points'],5.8)
        for j,p in enumerate(ps[1:-1],1):
            a,b=ps[j-1],ps[j+1];length=distance(a,b)
            for side in [-1,1]:
                offset=3.8+RNG.uniform(-.15,.5)
                candidates.append((p[0]-(b[1]-a[1])/length*offset*side,p[1]+(b[0]-a[0])/length*offset*side))
    RNG.shuffle(candidates)
    candidates.extend((RNG.uniform(-66,66),RNG.uniform(-64,65)) for _ in range(12000))
    for p in candidates:
        if len(plots)>=136:break
        size=RNG.uniform(1.15,1.78);r=size*1.46;i=district_at(p)
        if sum(t['district']==i for t in plots)>=24:continue
        if not clear(p,r) or any(distance(p,t['at'])<r+t['radius']+.35 for t in plots+heaps):continue
        ri=min(range(len(routes)),key=lambda j:closest(p,routes[j]['points'])[0]);d,q,_=closest(p,routes[ri]['points'])
        if d>12:continue
        kind=['cake','pancake','burger','donut'][(len(plots)+i*3)%4]
        floors=RNG.choice([2,3]) if len(plots)%4==0 else RNG.choice([4,5,6,7])
        if kind=='donut':floors+=1
        if kind=='burger':floors=min(floors,5)
        plots.append({'at':p,'size':size,'radius':r,'yaw':math.atan2(q[0]-p[0],q[1]-p[1]),'kind':kind,
                      'floors':floors,'flavor':(i+len(plots)//5)%4,'district':i,'route':ri,'role':'shop' if floors<=3 else 'housing'})
    # Two deliberately different height accents in the largest districts.
    for i in range(len(districts)):
        choices=[t for t in plots if t['district']==i and t['role']!='shop']
        choices.sort(key=lambda t:distance(t['at'],centers[i]))
        for anchor in choices[:2 if i in [1,4] else 1]:
            anchor['floors']=9 if anchor['kind']!='burger' else 6;anchor['role']='landmark'
    for t in plots:
        if t['role']=='shop':t['family']='cakery' if t['kind'] in ['cake','pancake'] else 'diner'
        elif t['role']=='landmark':
            t['family']=['wedding_cake','wafer_gate','berry_water_tower'][t['district']%3]
        else:t['family']='apartments'
    snacks=[];bins={}
    for attempt in range(90000):
        if len(snacks)>=960:break
        p=(RNG.uniform(-69,69),RNG.uniform(-67,68));i=district_at(p)
        if road_space.hits(p,.75) or walking_space.hits(p,.70):continue
        if distance(p,(1,23))<1.5:continue
        if any(distance(p,t['at'])<t['radius']+.70 for t in plots+heaps+starters):continue
        cell=(int(p[0]//1.4),int(p[1]//1.4))
        if any(distance(p,q)<1.35 for x in range(cell[0]-1,cell[0]+2) for z in range(cell[1]-1,cell[1]+2) for q in bins.get((x,z),[])):continue
        bins.setdefault(cell,[]).append(p)
        snacks.append({'at':p,'yaw':RNG.uniform(-math.pi,math.pi),'kind':attempt%10,'size':.42+(attempt%3)*.07,'flavor':i%4})
    plan={'version':4,'nodes':nodes,'roads':roads,'traffic':{'points':traffic,'half_width':3.25},'traffic_routes':[{'name':'Grand Glaze Loop','points':traffic,'half_width':3.25,'lane_offset':1.35},{'name':'Market Delivery Loop','points':inner,'half_width':2.7,'lane_offset':1.0}],
            'districts':districts,'routes':routes,'plots':plots,'heaps':heaps,'starters':starters,'snacks':snacks,
            'plazas':[{'at':[1,23],'radii':[8.1,6.7]}]}
    extend_outer_districts(plan)
    return plan


def extend_outer_districts(plan):
    """Append a connected edible outer district without rescaling old content.

    Old traffic centerlines stay unchanged. New connector roads avoid existing
    building/heap envelopes; intersected walking runs are clipped and frontage
    directions are recomputed against the actual retained walking geometry.
    """
    rng=random.Random(2026092907)
    old_counts={key:len(plan[key]) for key in ['nodes','roads','routes','plots','heaps','snacks','districts']}
    roads=plan['roads'];nodes=plan['nodes'];plots=plan['plots'];heaps=plan['heaps']
    ring=[(-72,-73),(0,-89),(74,-71),(89,0),(72,74),(0,89),(-74,72),(-89,0)]
    offset=len(nodes)
    nodes.extend({'at':p} for p in ring)
    for i in range(len(ring)):
        a,b,c,d=[ring[j%len(ring)] for j in (i-1,i,i+1,i+2)]
        points=[]
        for j in range(33):
            t=j/32
            points.append(tuple(.5*((2*b[k])+(-a[k]+c[k])*t+(2*a[k]-5*b[k]+4*c[k]-d[k])*t*t+(-a[k]+3*b[k]-3*c[k]+d[k])*t*t*t) for k in range(2)))
        roads.append({'name':'Sugar Promenade %02d'%i,'from':offset+i,'to':offset+(i+1)%8,
                      'points':points,'half_width':2.4,'class':'outer_boulevard','extension':True})
    obstacles=[(p['at'],p['radius']) for p in plots+heaps]
    def segment_clear(a,b):
        if max(abs(a[0]),abs(a[1]),abs(b[0]),abs(b[1]))>PLAY_LIMIT-3:return False
        return all(closest(p,[a,b])[0]>=r+2.7 for p,r in obstacles)
    def connector(start,end):
        if segment_clear(start,end):return resample([start,end],.8)
        # A small bounded construction-time grid avoids moving old buildings.
        step=1.5;initial=(0,0);cost={initial:0.0};previous={};queue=[(distance(start,end),initial)]
        def point(cell):return start[0]+cell[0]*step,start[1]+cell[1]*step
        goal=None
        while queue and len(cost)<20000:
            _,cell=heapq.heappop(queue);a=point(cell)
            if distance(a,end)<3 and segment_clear(a,end):goal=cell;break
            for dx,dz in [(1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)]:
                nxt=cell[0]+dx,cell[1]+dz;b=point(nxt)
                score=cost[cell]+distance(a,b)
                if score>=cost.get(nxt,1e20) or not segment_clear(a,b):continue
                cost[nxt]=score;previous[nxt]=cell;heapq.heappush(queue,(score+distance(b,end),nxt))
        if goal is None:raise RuntimeError('No clear outer connector: '+str((start,end)))
        cells=[goal]
        while cells[-1]!=initial:cells.append(previous[cells[-1]])
        raw=[point(c) for c in reversed(cells)]+[end];simple=[raw[0]];i=0
        while i<len(raw)-1:
            j=len(raw)-1
            while j>i+1 and not segment_clear(raw[i],raw[j]):j-=1
            simple.append(raw[j]);i=j
        return resample(simple,.8)
    for name,start,target in [('Marshmallow Rise',3,1),('Syrup Quay',6,3),('Custard Link',8,5),('Cookie Approach',1,7)]:
        roads.append({'name':name,'from':start,'to':offset+target,
                      'points':connector(nodes[start]['at'],ring[target]),'half_width':2.4,'class':'outer_connector','extension':True})
    road_space=Corridors(roads)
    def safe_runs(points,half_width):
        runs=[];run=[]
        for p in resample(points,.6):
            if (not road_space.hits(p,half_width+.30) and max(abs(p[0]),abs(p[1]))<PLAY_LIMIT-1
                    and all(distance(p,q)>=r+half_width+.30 for q,r in obstacles)):run.append(p)
            else:
                if len(run)>10:runs.append(run)
                run=[]
        if len(run)>10:runs.append(run)
        return runs
    routes=[]
    for original in plan['routes']:
        for index,run in enumerate(safe_runs(original['points'],original['half_width'])):
            route=dict(original);route['points']=run
            if index:route['name']+=' Section %d'%(index+1)
            routes.append(route)
    for edge in range(old_counts['roads'],len(roads)):
        road=roads[edge];points=resample(road['points'],.6)
        for side in [-1,1]:
            walk=[]
            for i,p in enumerate(points):
                a=points[max(0,i-1)];b=points[min(len(points)-1,i+1)];length=distance(a,b)
                shift=road['half_width']+1.85
                walk.append((p[0]-(b[1]-a[1])/length*shift*side,p[1]+(b[0]-a[0])/length*shift*side))
            for index,run in enumerate(safe_runs(walk,1.05)):
                routes.append({'name':road['name']+(' Outer Walk' if side<0 else ' Inner Walk')+' %d'%index,
                               'points':run,'half_width':1.05,'road':edge,'extension':True})
    plan['routes']=routes;walking_space=Corridors(routes)
    new_centers=[(0,-91),(91,0),(0,91),(-91,0)]
    for name,p in zip(['Marshmallow Reach','Syrup Waterfront','Custard Commons','Cookie End'],new_centers):
        x,z=p
        polygon=[(-98,-98),(98,-98),(98,-70),(-98,-70)] if z<0 else [(-98,70),(98,70),(98,98),(-98,98)] if z>0 else [(70,-70),(98,-70),(98,70),(70,70)] if x>0 else [(-98,-70),(-70,-70),(-70,70),(-98,70)]
        plan['districts'].append({'name':name,'center':p,'polygon':polygon,'extension':True})
    def district_at(p):return old_counts['districts']+min(range(4),key=lambda i:distance(p,new_centers[i]))
    def clear(p,r):
        return (max(abs(p[0]),abs(p[1]))<PLAY_LIMIT-r and not road_space.hits(p,r+.3)
                and not walking_space.hits(p,r+.3) and all(distance(p,q['at'])>r+q['radius']+.4 for q in plots+heaps))
    for p in [(-87,-87),(87,87)]:
        if not clear(p,3.7):raise RuntimeError('Outer heap loses its reserved clear envelope: '+str(p))
        heaps.append({'at':p,'radius':3.7,'yaw':.31 if p[0]<0 else -.42,'district':district_at(p),'extension':True})
    candidates=[]
    for edge in range(old_counts['roads'],old_counts['roads']+8):
        points=resample(roads[edge]['points'],4.5)
        for i,p in enumerate(points[1:-1],1):
            a,b=points[i-1],points[i+1];length=distance(a,b)
            for side in [-1,1]:
                shift=7.9
                candidates.append((edge-old_counts['roads'],(p[0]-(b[1]-a[1])/length*shift*side,p[1]+(b[0]-a[0])/length*shift*side)))
    rng.shuffle(candidates);per_edge={i:0 for i in range(8)}
    for edge,p in candidates:
        if len(plots)>=old_counts['plots']+24:break
        if per_edge[edge]>=3:continue
        size=1.15+rng.random()*.26;r=size*1.46
        if not clear(p,r):continue
        ri=min(range(len(routes)),key=lambda i:closest(p,routes[i]['points'])[0]);_,q,_=closest(p,routes[ri]['points'])
        index=len(plots)-old_counts['plots'];kind=['cake','burger','pancake','donut'][index%4];floors=2+index%3
        plots.append({'at':p,'size':size,'radius':r,'yaw':math.atan2(q[0]-p[0],q[1]-p[1]),'kind':kind,
                      'floors':floors,'flavor':index%4,'district':district_at(p),'route':ri,
                      'role':'shop' if floors==2 else 'housing','family':('cakery' if kind in ['cake','pancake'] else 'diner') if floors==2 else 'apartments','extension':True})
        per_edge[edge]+=1
    if sum(per_edge.values())!=24:raise RuntimeError('Incomplete outer frontage: '+str(per_edge))
    # Front doors face retained sidewalks, including junction clips. Positions,
    # sizes, levels and old traffic geometry are preserved.
    for plot in plots:
        ri=min(range(len(routes)),key=lambda i:closest(plot['at'],routes[i]['points'])[0]);_,q,_=closest(plot['at'],routes[ri]['points'])
        plot['route']=ri;plot['yaw']=math.atan2(q[0]-plot['at'][0],q[1]-plot['at'][1])
    snacks=[]
    for snack in plan['snacks']:
        p=snack['at']
        if road_space.hits(p,.75) or walking_space.hits(p,.70):
            # Only new connector intersections can affect old loose snacks.
            found=None
            for radius in range(1,21):
                for j in range(24):
                    q=(p[0]+math.cos(j*math.tau/24)*radius*.6,p[1]+math.sin(j*math.tau/24)*radius*.6)
                    if clear(q,.8) and all(distance(q,x['at'])>1.35 for x in snacks+plan['snacks']):found=q;break
                if found is not None:break
            if found is None:raise RuntimeError('Cannot safely relocate intersected snack')
            snack=dict(snack);snack['at']=found
        snacks.append(snack)
    for attempt in range(20000):
        if len(snacks)>=old_counts['snacks']+120:break
        side=attempt%4;along=rng.uniform(-94,94);outer=rng.uniform(77,94)
        p=(along,-outer) if side==0 else (outer,along) if side==1 else (along,outer) if side==2 else (-outer,along)
        if not clear(p,.8) or any(distance(p,x['at'])<1.35 for x in snacks):continue
        snacks.append({'at':p,'yaw':rng.uniform(-math.pi,math.pi),'kind':attempt%10,'size':.42+(attempt%3)*.07,'flavor':side,'extension':True})
    if len(snacks)!=old_counts['snacks']+120:raise RuntimeError('Incomplete outer snack district')
    plan['snacks']=snacks;plan['world_half']=WORLD_HALF;plan['play_limit']=PLAY_LIMIT
    plan['extension']={'baseline_counts':old_counts,'additional_plots':24,'additional_heaps':2,'additional_snacks':120,
                       'maximum_additional_food_bodies':358,'traffic_paths_preserved':True}


def atlas(plan):
    width=2048;scale=width/(WORLD_HALF*2);data=bytearray(bytes((99,210,178))*width*width)
    def pixel(x,z,color):
        if 0<=x<width and 0<=z<width:data[(z*width+x)*3:(z*width+x)*3+3]=bytes(color)
    def capsule(a,b,r,color):
        aa=((a[0]+WORLD_HALF)*scale,(a[1]+WORLD_HALF)*scale);bb=((b[0]+WORLD_HALF)*scale,(b[1]+WORLD_HALF)*scale);rr=r*scale
        dx,dz=bb[0]-aa[0],bb[1]-aa[1];den=max(.00001,dx*dx+dz*dz)
        for z in range(max(0,int(min(aa[1],bb[1])-rr-1)),min(width,int(max(aa[1],bb[1])+rr+2))):
            for x in range(max(0,int(min(aa[0],bb[0])-rr-1)),min(width,int(max(aa[0],bb[0])+rr+2))):
                t=max(0,min(1,((x+.5-aa[0])*dx+(z+.5-aa[1])*dz)/den))
                if (x+.5-aa[0]-dx*t)**2+(z+.5-aa[1]-dz*t)**2<rr*rr:pixel(x,z,color)
    def ellipse(center,radii,color):
        a,b=radii;cx,cz=center
        for z in range(max(0,int((cz-b+WORLD_HALF)*scale)),min(width,int((cz+b+WORLD_HALF)*scale)+1)):
            for x in range(max(0,int((cx-a+WORLD_HALF)*scale)),min(width,int((cx+a+WORLD_HALF)*scale)+1)):
                if ((x/scale-WORLD_HALF-cx)/a)**2+((z/scale-WORLD_HALF-cz)/b)**2<1:pixel(x,z,color)
    for p in plan['plots']:
        ellipse(p['at'],(p['radius']+1.0,p['radius']+.7),[(92,198,157),(114,215,167),(84,193,163)][p['district']%3])
    for route in plan['routes']:
        for extra,color in [(1.0,(255,243,207)),(.25,(240,145,123)),(0,(246,210,145))]:
            for a,b in zip(route['points'],route['points'][1:]):capsule(a,b,route['half_width']+extra,color)
    for p in plan['plazas']:
        a,b=p['radii'];ellipse(p['at'],(a,b),(249,139,157));ellipse(p['at'],(a-.35,b-.35),(255,236,194))
        ellipse(p['at'],(2.2,1.6),(249,197,119))
    for road in plan['roads']:
        for extra,color in [(.35,(246,124,145)),(0,(255,231,178))]:
            for a,b in zip(road['points'],road['points'][1:]):capsule(a,b,road['half_width']+extra,color)
        ps=resample(road['points'],1.1)
        for i in range(0,len(ps)-1,4):capsule(ps[i],ps[i+1],.085,(240,144,119))
    # Small junction aprons make branch topology readable at the play camera.
    degree={i:0 for i in range(len(plan['nodes']))}
    for road in plan['roads']:degree[road['from']]+=1;degree[road['to']]+=1
    for i,count in degree.items():
        if count>=3:ellipse(plan['nodes'][i]['at'],(2.0,2.0),(255,238,196))
    def chunk(kind,body):return struct.pack('>I',len(body))+kind+body+struct.pack('>I',zlib.crc32(kind+body)&0xffffffff)
    raw=b''.join(b'\0'+data[z*width*3:(z+1)*width*3] for z in range(width))
    png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,width,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')
    (OUT/'streets.png').write_bytes(png)
    (EVIDENCE/'streets.ppm').write_bytes(f'P6\n{width} {width}\n255\n'.encode()+data)


if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True);EVIDENCE.mkdir(parents=True,exist_ok=True)
    plan=make_plan();(OUT/'neighborhoods.json').write_text(json.dumps(plan,indent=2)+'\n')
    atlas(plan)
    print(json.dumps({key:len(plan[key]) for key in ['districts','roads','routes','plots','heaps','snacks']}))
