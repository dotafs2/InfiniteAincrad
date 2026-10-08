"""Independent density and new-ground-body clearance from an actual scene capture.

Pure geometry; no source changes, renderer claims or elapsed-time benchmark.
"""
from pathlib import Path
import argparse, collections, hashlib, json, math

def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def segment_distance(p,a,b):
    dx=b[0]-a[0];dz=b[1]-a[1]
    t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz)))
    return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dz)
def segment_bins(routes,margin=0):
    bins=collections.defaultdict(list)
    for route in routes:
        for a,b in zip(route['points'],route['points'][1:]):
            radius=route['half_width']+margin
            row=(a,b,route['half_width'])
            for i in range(math.floor((min(a[0],b[0])-radius)/8),math.floor((max(a[0],b[0])+radius)/8)+1):
                for j in range(math.floor((min(a[1],b[1])-radius)/8),math.floor((max(a[1],b[1])+radius)/8)+1): bins[i,j].append(row)
    return bins
def hits(point,bins,margin):
    for i in range(math.floor((point[0]-margin)/8),math.floor((point[0]+margin)/8)+1):
        for j in range(math.floor((point[1]-margin)/8),math.floor((point[1]+margin)/8)+1):
            for a,b,width in bins.get((i,j),[]):
                if segment_distance(point,a,b)<width+margin:return True
    return False

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--plan',type=Path,required=True);parser.add_argument('--physical',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    plan=json.loads(args.plan.read_text());capture=json.loads(args.physical.read_text());assert capture['plan_sha256']==digest(args.plan)
    roads=segment_bins(plan['roads']);walks=segment_bins(plan['routes']);rows=[]
    for district in plan['districts'][-4:]:
        poly=district['polygon'];xmin=min(p[0] for p in poly);xmax=max(p[0] for p in poly);zmin=min(p[1] for p in poly);zmax=max(p[1] for p in poly)
        foods=[f for f in capture['ground_food'] if xmin-3<=f['at'][0]<xmax+3 and zmin-3<=f['at'][1]<zmax+3]
        total=axis=oriented=0
        for x in range(math.ceil(xmin),math.floor(xmax)):
            for z in range(math.ceil(zmin),math.floor(zmax)):
                at=(x+.5,z+.5)
                if hits(at,roads,1.5):continue
                total+=1
                if any(abs(at[0]-f['at'][0])<f['half'][0] and abs(at[1]-f['at'][1])<f['half'][1] for f in foods):axis+=1
                for f in foods:
                    dx=at[0]-f['at'][0];dz=at[1]-f['at'][1];c=math.cos(f['yaw']);s=math.sin(f['yaw'])
                    if abs(c*dx-s*dz)<f['half'][0] and abs(s*dx+c*dz)<f['half'][1]:oriented+=1;break
        rows.append({'district':district['name'],'eligible':total,'occupied_axis':axis,'ratio_axis':axis/total,'ratio_rotated_rectangles':oriented/total})
    new_snacks=[s for s in plan['snacks'] if s.get('extension')];new_ground=[]
    for food in capture['ground_food']:
        if food['tower']>=136 or food['pile'] in (12,13) or any(math.dist(food['at'],s['at'])<.0001 for s in new_snacks):new_ground.append(food)
    violations=[]
    for food in new_ground:
        r=food['collision_radius'];assert r>0
        if hits(food['at'],roads,r+.01):violations.append({'kind':'road','food':food})
        if hits(food['at'],walks,r+.01):violations.append({'kind':'walk','food':food})
        for other in capture['ground_food']:
            if other is food or food['pile']>=0 and food['pile']==other['pile']:continue
            # Existing heap roots legitimately touch within their own pyramid.
            if math.dist(food['at'],other['at'])<r+other['collision_radius']-.025:violations.append({'kind':'body','a':food,'b':other})
    result={'plan_sha256':digest(args.plan),'capture_sha256':digest(args.physical),'districts':rows,'new_unsupported_foods':len(new_ground),'clearance_violations':violations,'density_pass':all(r['ratio_axis']>=.12 for r in rows),'scope':'Actual unsupported-body half extents reproduce the unchanged gate; rotated rectangles are an independent presentation-footprint estimate. New body clearances use actual collider circumradii. No image or performance claim.'}
    args.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='clearance_violations'},indent=2));print('clearance violations',len(violations))
    if not result['density_pass'] or violations:raise SystemExit(1)
if __name__=='__main__':main()
