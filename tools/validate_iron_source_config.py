"""Check one GM-authored finite salvage spec; physical approval is a separate trial."""
import argparse
import json
import math
from pathlib import Path
import re


def validate(value):
    errors=[]
    if not isinstance(value,dict) or set(value) != {'id','label','material','initial_stock','position','access'}:
        return ['One exact material-source specification is required']
    if not isinstance(value['id'],str) or not re.fullmatch(r'[A-Za-z0-9_.:-]{1,64}',value['id']): errors.append('invalid id')
    if not isinstance(value['label'],str) or not 1<=len(value['label'])<=80 or not value['label'].isascii(): errors.append('bounded English label required')
    if value['material']!='iron' or value['access']!='public': errors.append('public iron source required')
    if type(value['initial_stock']) is not int or not 1<=value['initial_stock']<=3: errors.append('stock must be 1..3 units')
    pos=value['position']
    if (not isinstance(pos,list) or len(pos)!=3 or
            any(type(v) not in (int,float) or not math.isfinite(v) for v in pos)):
        errors.append('finite [x,y,z] required')
    elif abs(pos[0])>64 or abs(pos[2])>64 or not 0<=pos[1]<=2: errors.append('position outside town bounds')
    return errors


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('path',type=Path)
    args=parser.parse_args()
    errors=validate(json.loads(args.path.read_text(encoding='utf-8-sig')))
    print(json.dumps(dict(ok=not errors,errors=errors,physical_trial_passed=False)))
    raise SystemExit(1 if errors else 0)
