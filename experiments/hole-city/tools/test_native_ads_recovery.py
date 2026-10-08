"""Execute the actual Swift advertising methods against controlled SDK boundaries.

No real network, consent, advertising or payment request occurs. The timer
clock alone is replaced by a manually released clock; original/current methods are
compiled separately and every source/fixture digest is retained.
"""
from pathlib import Path
from datetime import datetime,timezone
import argparse,hashlib,json,plistlib,re,subprocess
ROOT=Path(__file__).resolve().parents[1]
SCENARIOS=['network','background','suspend-update','denied','cached','form-failure','privacy-race','privacy-closes-first','reward','backoff','privacy-inactive','haptic']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--source',required=True,type=Path)
 parser.add_argument('--evidence',required=True,type=Path)
 parser.add_argument('--report',required=True,type=Path)
 args=parser.parse_args();source=args.source.resolve();out=args.evidence.resolve();out.mkdir(parents=True,exist_ok=False)
 raw=source.read_text();assert raw.count('    @objc func initializeCommerce()')==1
 ads=raw.split('    @objc func initializeCommerce()',1)[0]+'}\n'
 ads=re.sub(r'^import (UIKit|StoreKit|GoogleMobileAds|UserMessagingPlatform)\n','',ads,flags=re.M)
 occurrences=ads.count('UInt64(delay) * 1_000_000_000')
 assert occurrences in (1,2)
 ads=ads.replace('try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)','try await FixtureClock.sleep(seconds: delay)')
 extracted=out/'actual-ads-methods.swift';extracted.write_text(ads)
 app=out/'Acceptance.app/Contents';binary=app/'MacOS/Acceptance';binary.parent.mkdir(parents=True)
 (app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.hole-feast.ads-recovery-fixture','CFBundleExecutable':'Acceptance','HoleFeastTestAds':True,'HoleFeastRewardedUnit':'ca-app-pub-3940256099942544/1712485313'}))
 stubs=ROOT/'tests/native_ads_recovery_stubs.swift';harness=ROOT/'tests/native_ads_recovery_harness.swift'
 with (out/'compile.log').open('w') as log:
  r=subprocess.run(['xcrun','swiftc','-swift-version','5','-parse-as-library',str(stubs),str(extracted),str(harness),'-o',str(binary)],stdout=log,stderr=subprocess.STDOUT,timeout=180)
 if r.returncode:raise RuntimeError('Actual native ad-method compile failed; see retained compile.log')
 results=[]
 for scenario in SCENARIOS:
  r=subprocess.run([str(binary),scenario],capture_output=True,text=True,timeout=15)
  (out/(scenario+'.log')).write_text(r.stdout+r.stderr)
  rows=[x for x in r.stdout.splitlines() if x.startswith('{')]
  if not rows:raise RuntimeError('No fixture report for '+scenario+'; exact output retained')
  report=json.loads(rows[-1]);assert report['scenario']==scenario
  report['exit_code']=r.returncode;results.append(report)
 result={'at_utc':datetime.now(timezone.utc).isoformat(),'scope':'Actual extracted native Swift advertising and haptic methods, controlled SDK/UI boundaries and manually released timer clock; no live Google/Apple request or physical vibration. Not physical SDK callback acceptance.','source_sha256':sha(source),'extracted_sha256':sha(extracted),'fixtures_sha256':{str(p.relative_to(ROOT)):sha(p) for p in [stubs,harness]},'timer_clock':'Manual boundary, actual computed seconds retained','timer_expression_substitutions':occurrences,'checks':sum(r['checks'] for r in results),'failures':[{'scenario':r['scenario'],'failure':x} for r in results for x in r['failures']],'scenarios':results}
 args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'checks':result['checks'],'failures':result['failures'],'source_sha256':result['source_sha256']}))
 return 1 if result['failures'] else 0
if __name__=='__main__':raise SystemExit(main())
