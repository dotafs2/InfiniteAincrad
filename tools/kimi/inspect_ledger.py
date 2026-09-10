"""Inspect a transferred existing ledger/guard pair; never initialize or spend."""
import argparse
import json
from pathlib import Path
from kimi_budget import Ledger, Policy, CityValidationPolicy

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('ledger', type=Path)
args = parser.parse_args()
guard = json.loads(args.ledger.with_suffix('.guard.json').read_text(encoding='utf-8'))
policy_type = CityValidationPolicy if 'request_limit' in guard['policy'] else Policy
ledger = Ledger(args.ledger, policy=policy_type(**guard['policy']))
print(json.dumps(ledger.status(), ensure_ascii=False, indent=2))
