from pathlib import Path
import importlib.util,json,math,time
ROOT=Path(__file__).resolve().parents[3]
spec=importlib.util.spec_from_file_location('gen',ROOT/'tools/build_food_neighborhoods.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
base=Path(__file__).resolve().parent
plan=json.loads((base/'before/assets/food_city/neighborhoods.json').read_text())
plots=plan['plots'][:136];heaps=plan['heaps'];oldsnacks=plan['snacks'][:960]
road=g.Corridors(plan['roads']);walk=g.Corridors(plan['routes'])
bounds=json.loads((base/'mesh-bounds.json').read_text())
recipe=['bacon','egg','cake','donut','burger','cookie','berry','sushi','pancake','pizza']
def dims(s):
 kind=recipe[s['kind']];key=kind+('_'+str(s['flavor']%4) if kind in ['cake','donut','cookie'] else '')
 return bounds[key]['size']
def zone(p):return 0 if p[1]<-70 else 2 if p[1]>70 else 1 if p[0]>70 else 3
obstacles=[(p['at'],p['radius']) for p in plots+heaps]+[(p['at'],math.hypot(dims(p)[0],dims(p)[2])*.5*p['size']) for p in oldsnacks]
def max_space(p):
 r=min(96-max(abs(p[0]),abs(p[1])),min(g.distance(p,q)-r-.35 for q,r in obstacles),8.5)
 if r<.75:return 0
 if road.hits(p,.3) or walk.hits(p,.3):return 0
 lo=0;hi=r
 for _ in range(8):
  mid=(lo+hi)/2
  if road.hits(p,mid+.3) or walk.hits(p,mid+.3):hi=mid
  else:lo=mid
 return lo
print('compute candidates',flush=True);now=time.time()
candidates=[]
for x in range(-94,95,2):
 for z in range(-94,95,2):
  if max(abs(x),abs(z))<71:continue
  p=(x+.33*math.sin(z),z+.33*math.cos(x));r=max_space(p)
  if r>.75:candidates.append([p,r,zone(p)])
print('candidates',len(candidates),'seconds',time.time()-now,flush=True)
def place(district,cap,min_radius=.5):
 selected=max((c for c in candidates if c[2]==district),key=lambda c:min(cap,c[1]),default=None)
 r=min(cap,selected[1])
 if r<min_radius:raise ValueError(('space',district,r))
 p=selected[0]
 for c in candidates:c[1]=min(c[1],g.distance(p,c[0])-r-.35)
 return p,r
newplots=[]
for i,district in enumerate([0,2,1,3]*5+[0,2,0,2]):
 proto=dict(plan['plots'][136+i]);p,r=place(district,[5.4,6.1,4.8,5.7,5.1,6.3][i%6])
 # Retain a conservative diagonal envelope for both square and rounded tower recipes.
 proto.update(at=p,size=r/1.5,radius=r,district=7+district);newplots.append(proto)
print('tower sizes',[round(p['size'],2) for p in newplots],flush=True)
newsnacks=[];counts=[0]*4
for i,s in enumerate(plan['snacks'][960:]):
 district=[0,2,1,3][i%4];proto=dict(s)
 p,r=place(district,[2.1,2.7,3.0,2.4,1.8][i%5] if i<64 else [1.0,1.3,1.6][i%3] if i<96 else .80)
 dx,_,dz=dims(proto)
 # Box foods use their true diagonal. Rounded food uses its actual radius.
 factor=math.hypot(dx,dz)*.5 if recipe[proto['kind']] in ['bacon','sushi'] else max(dx,dz)*.5
 proto.update(at=p,size=r/factor,district=7+district);newsnacks.append(proto);counts[district]+=1
print('snack counts',counts,'max sizes',max(s['size'] for s in newsnacks),flush=True)
plan['plots']=plots+newplots;plan['snacks']=oldsnacks+newsnacks
for p in plan['plots']:
 ri=min(range(len(plan['routes'])),key=lambda i:g.closest(p['at'],plan['routes'][i]['points'])[0]);_,q,_=g.closest(p['at'],plan['routes'][ri]['points']);p['route']=ri;p['yaw']=math.atan2(q[0]-p['at'][0],q[1]-p['at'][1])
(base/'candidate-plan.json').write_text(json.dumps(plan,indent=2)+'\n')
# Lower-bound coverage of newly authored ground foods and tower base AABBs.
rects=[]
for p in newplots:
 kind=p['kind'];family=p['family'];size=p['size']
 if family in ['cakery','diner']:xz=(2.04,2.04)
 else:
  key=kind+'_tower'+('_'+str(p['flavor']) if kind!='burger' else '');xz=(bounds[key]['size'][0],bounds[key]['size'][2])
 rects.append((p['at'],(xz[0]*size*.5,xz[1]*size*.5)))
for s in newsnacks:
 d=dims(s);rects.append((s['at'],(d[0]*s['size']*.5,d[2]*s['size']*.5)))
coverage=[]
for d in plan['districts'][7:]:
 xs=[p[0] for p in d['polygon']];zs=[p[1] for p in d['polygon']];occupied=total=0
 for x in range(min(xs),max(xs)):
  for z in range(min(zs),max(zs)):
   p=(x+.5,z+.5)
   if road.hits(p,1.5):continue
   total+=1
   if any(abs(p[0]-q[0])<r[0] and abs(p[1]-q[1])<r[1] for q,r in rects):occupied+=1
 coverage.append({'name':d['name'],'occupied':occupied,'total':total,'ratio':occupied/total})
print(json.dumps(coverage,indent=2),flush=True)
(base/'candidate-coverage.json').write_text(json.dumps(coverage,indent=2)+'\n')
