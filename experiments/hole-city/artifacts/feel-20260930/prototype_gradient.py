from pathlib import Path
import importlib.util,json,math,collections,time
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('urban',ROOT/'tools/build_food_neighborhoods.py');u=importlib.util.module_from_spec(spec);spec.loader.exec_module(u)
plan=json.loads((ROOT/'artifacts/feel-20260930/food-before/assets/food_city/neighborhoods.json').read_text())
unit=[1.041588,.908391,1.05,1.,.99,.9,.699947,1.240847,.97,1.]
envelopes=[1.05,.94,1.06,1.01,1.,.91,.73,1.25,.98,1.01]
centers=[d['center'] for d in plan['districts'][:7]]
def district(p):return min(range(7),key=lambda i:u.distance(p,centers[i]))
selected=[]
for d in range(7):
 candidates=[i for i,s in enumerate(plan['snacks'][:960]) if district(s['at'])==d]
 candidates.sort(key=lambda i:u.distance(plan['snacks'][i]['at'],centers[d]))
 for j,index in enumerate(candidates[:26]):
  level=2 if j<14 else 3 if j<22 else 4
  selected.append((index,d,level))
selected_ids={v[0] for v in selected}
obstacles=[(p['at'],p['radius']) for p in plan['plots']+plan['heaps']+plan['starters']]
obstacles += [(s['at'],envelopes[s['kind']]*s['size']) for i,s in enumerate(plan['snacks']) if i not in selected_ids]
road=u.Corridors(plan['roads']);walk=u.Corridors(plan['routes'])
candidates=[]
for x in range(-75,76):
 for z in range(-74,75):
  p=(x*.9+.13*math.sin(z),z*.9+.13*math.cos(x))
  maxr=min(68-max(abs(p[0]),abs(p[1])),u.distance(p,(1,23))-1.6,min(u.distance(p,q)-r-.18 for q,r in obstacles),2.1)
  if maxr<.93 or road.hits(p,1.20) or walk.hits(p,1.20):continue
  lo=0;hi=maxr
  for _ in range(7):
   mid=(lo+hi)*.5
   if road.hits(p,mid+.3) or walk.hits(p,mid+.3):hi=mid
   else:lo=mid
  if lo>=.93:candidates.append([p,lo,district(p)])
print('candidates',len(candidates),collections.Counter(c[2] for c in candidates),flush=True)
results=[]
# Largest objects get real ground clearance before filling smaller gaps.
for index,d,level in sorted(selected,key=lambda row:-row[2]):
 s=plan['snacks'][index];target={2:.96,3:1.35,4:1.9}[level];size=target/unit[s['kind']];radius=size*envelopes[s['kind']]
 anchor=(1,23) if d==4 else centers[d]
 viable=[c for c in candidates if c[2]==d and c[1]>=radius]
 if not viable:
  print('FAILED',index,d,level,radius,collections.Counter(x['district'] for x in results));break
 chosen=min(viable,key=lambda c:u.distance(c[0],anchor))
 p=chosen[0]
 s.update(at=p,size=size,growth_level=level,growth_radius=target,growth_district=d,growth_envelope=radius)
 for c in candidates:c[1]=min(c[1],u.distance(c[0],p)-radius-.18)
 results.append({'district':d,'level':level,'at':p,'distance':u.distance(p,anchor),'radius':radius})
else:
 (ROOT/'artifacts/feel-20260930/prototype-plan.json').write_text(json.dumps(plan,indent=2)+'\n')
 print('PASS',len(results),collections.Counter((r['district'],r['level']) for r in results),'spawn',[(r['level'],round(r['distance'],2)) for r in results if r['district']==4],flush=True)
(ROOT/'artifacts/feel-20260930/prototype-placement.json').write_text(json.dumps(results,indent=2)+'\n')
