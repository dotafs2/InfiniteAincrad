"""Attach the project's StoreKit 2 / AdMob adapter to a fresh native export.

SDK ZIPs must match Google's package checksums. Never accepts test advertising
IDs in production mode and never changes the verified baseline native export.
"""
import argparse
import hashlib
import importlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
PINS = {
    "gma.zip": "310516d18f0d600c9e45ed42b955a6b8ec52108d380f7cd8ed1e424e9d3fec22",
    "ump.zip": "90fe6bf3b0f4ce0d0199628c0871de58b6f673375148b98d52348aecc86db231",
    "godot.tar.gz": "e954996374cbd1cb5d72e0e3781cc537408e6ce73b010b12c6c2f308a820690a",
}
TEST_APP = "ca-app-pub-3940256099942544~1458002511"
TEST_REWARDED = "ca-app-pub-3940256099942544/1712485313"
# Google's published buyer identifiers, reviewed October 1, 2026.
# https://developers.google.com/admob/ios/quick-start#update_your_infoplist
# SKAdNetwork attribution does not grant ATT or enable personalized ads.
SKAD_NETWORK_IDS = tuple("""
cstr6suwn9 4fzdc2evr5 2fnua5tdw4 ydx93a7ass p78axxw29g v72qych5uu
ludvb6z3bs cp8zw746q7 3sh42y64q3 c6k4g5qg8m s39g8k73mm wg4vff78zm
3qy4746246 f38h382jlk hs6bdukanm mlmmfzh3r3 v4nxqhlyqp wzmmz9fp6w
su67r6k2v3 yclnxrl5pm t38b2kh725 7ug5zh24hu gta9lk7p23 vutu7akeur
y5ghdn5j9k v9wttpbfk9 n38lu8286q 47vhws6wlr kbd757ywx3 9t245vhmpl
a2p9lx4jpn 22mmun2rn5 44jx6755aq k674qkevps 4468km3ulz 2u9pt9hc89
8s468mfl3y klf5c3l5u5 ppxm28t8ap kbmxgpxpgc uw77j35x4d 578prtvx9j
4dzt52r2t5 tl55sbb4fm c3frkrj4fj e5fvkxwrpn 8c4e2ghe7u 3rd42ekr43
97r2b46745 3qcr597p9d
""".split())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def object_id(name):
    return hashlib.sha256(("HoleFeastServices/" + name).encode()).hexdigest()[:24].upper()


def quoted(value):
    return json.dumps(str(value))


def configure(exported, dependencies, app_id, unit, test_ads):
    exported, dependencies = exported.resolve(), dependencies.resolve()
    if not exported.is_relative_to(ROOT / "build"):
        raise ValueError("Only an isolated local build export may be configured")
    if not re.fullmatch(r"ca-app-pub-\d{16}~\d{10}", app_id) or not re.fullmatch(r"ca-app-pub-\d{16}/\d{10}", unit):
        raise ValueError("Use real AdMob app/rewarded identifiers")
    if not test_ads and ("3940256099942544" in app_id or "3940256099942544" in unit):
        raise ValueError("Production builds must not contain Google's sample IDs")
    if app_id.split("~")[0] != unit.split("/")[0]:
        raise ValueError("AdMob app and rewarded unit must belong to the same publisher")
    project = exported / "SinkCity.xcodeproj/project.pbxproj"
    text = project.read_text()
    if "HoleFeastServices.swift" in text or (exported / "native-services.json").exists():
        raise ValueError("Native services already configured; use a fresh export")
    for filename, expected in PINS.items():
        if sha(dependencies / filename) != expected:
            raise ValueError("Dependency checksum mismatch: " + filename)
    godot = dependencies / "godot/godot-4.7.2-stable"
    sys.path[:0] = [str(godot), str(godot / "core"), str(godot / "core/extension")]
    header = importlib.import_module("make_interface_header")
    builders = importlib.import_module("core_builders")

    class EmptyClasses:
        def read(self):
            return []

    header.run([godot / "core/extension/gdextension_interface.gen.h"],
               [godot / "core/extension/gdextension_interface.json"], {})
    builders.disabled_class_builder([godot / "core/disabled_classes.gen.h"], [EmptyClasses()], {})

    native = exported / "NativeDependencies"
    native.mkdir()
    additions, references, sources, frameworks, resources = [], [], [], [], []

    def add(name, file_type, phase, path):
        reference, build = object_id(name), object_id(name + "/build")
        additions.append(f'\t\t{reference} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {file_type}; path = {quoted(path)}; sourceTree = SOURCE_ROOT; }};\n')
        references.append(f"\t\t\t\t{reference} /* {name} */,\n")
        additions.append(f"\t\t{build} /* {name} in {phase} */ = {{isa = PBXBuildFile; fileRef = {reference}; }};\n")
        {"Sources": sources, "Frameworks": frameworks, "Resources": resources}[phase].append(f"\t\t\t\t{build} /* {name} */,\n")

    for name in ("HoleFeastServices.swift", "HoleFeastPlugin.mm"):
        shutil.copy2(ROOT / "native/ios" / name, native / name)
        add(name, "sourcecode.swift" if name.endswith("swift") else "sourcecode.cpp.objcpp", "Sources", "NativeDependencies/" + name)
    sdk_names = (("gma", "GoogleMobileAds"), ("ump", "UserMessagingPlatform"))
    manifests = []
    for folder, name in sdk_names:
        source = dependencies / folder / (name + ".xcframework")
        shutil.copytree(source, native / source.name)
        add(source.name, "wrapper.xcframework", "Frameworks", "NativeDependencies/" + source.name)
        # These vendor frameworks contain static archives. Keep them linked,
        # not embedded as executable frameworks. Retain their full privacy files
        # in separate resource bundles for Apple's aggregate privacy report.
        bundle = native / (name + "Privacy.bundle")
        bundle.mkdir()
        privacy = source / "ios-arm64" / (name + ".framework") / "PrivacyInfo.xcprivacy"
        shutil.copy2(privacy, bundle / "PrivacyInfo.xcprivacy")
        (bundle / "Info.plist").write_bytes(plistlib.dumps({
            "CFBundleIdentifier": "io.github.dotafs2.sinkcity." + name.lower() + ".privacy",
            "CFBundleName": name + "Privacy", "CFBundlePackageType": "BNDL",
            "CFBundleVersion": "1", "CFBundleShortVersionString": "1.0",
        }))
        add(bundle.name, "wrapper.plug-in", "Resources", "NativeDependencies/" + bundle.name)
        manifests.append({"sdk": name, "sha256": sha(privacy)})
    for framework in ("StoreKit", "WebKit", "AdSupport", "AudioToolbox", "AVFoundation",
                      "CoreMedia", "CoreTelephony", "SystemConfiguration", "SafariServices", "CoreGraphics"):
        add(framework + ".framework", "wrapper.framework", "Frameworks",
            "System/Library/Frameworks/" + framework + ".framework")
        additions[-2] = additions[-2].replace("sourceTree = SOURCE_ROOT", "sourceTree = SDKROOT")

    def insert_list(identifier, rows):
        nonlocal text
        pattern = r"(" + re.escape(identifier) + r"[^\n]*= \{.*?\b(?:children|files) = \(\n)"
        text, count = re.subn(pattern, lambda m: m[1] + "".join(rows), text, count=1, flags=re.S)
        if count != 1:
            raise ValueError("Unexpected Xcode section: " + identifier)

    text = text.replace("\tobjects = {\n", "\tobjects = {\n" + "".join(additions), 1)
    insert_list("D0BCFE2B18AEBDA2004A7AAE", references)
    insert_list("D0BCFE3018AEBDA2004A7AAE", sources)
    insert_list("D0BCFE3118AEBDA2004A7AAE", frameworks)
    insert_list("D0BCFE3218AEBDA2004A7AAE", resources)
    text = text.replace('CLANG_CXX_LANGUAGE_STANDARD = "gnu++0x";', 'CLANG_CXX_LANGUAGE_STANDARD = "gnu++17";')
    settings = ("\n\t\t\t\tHEADER_SEARCH_PATHS = (\"$(inherited)\", " + quoted('"' + str(godot) + '"') + ", " + quoted('"' + str(godot / "platform/ios") + '"') + ");"
                "\n\t\t\t\tOTHER_CPLUSPLUSFLAGS = \"$(inherited) -DPTRCALL_ENABLED -DIOS_ENABLED -DUNIX_ENABLED -fno-exceptions -fno-rtti\";"
                "\n\t\t\t\tGCC_ENABLE_CPP_EXCEPTIONS = NO;"
                "\n\t\t\t\tGCC_ENABLE_CPP_RTTI = NO;"
                "\n\t\t\t\tSWIFT_INSTALL_OBJC_HEADER = YES;")
    text = text.replace("SWIFT_VERSION = 5.0;", "SWIFT_VERSION = 5.0;" + settings)
    text = text.replace('OTHER_LDFLAGS = "$(LD_CLASSIC_$(XCODE_VERSION_ACTUAL))  ";',
                        'OTHER_LDFLAGS = "$(LD_CLASSIC_$(XCODE_VERSION_ACTUAL)) -ObjC";')
    dummy = exported / "SinkCity/dummy.cpp"
    bootstrap = dummy.read_text()
    expected = "void godot_apple_embedded_plugins_initialize() {\n}"
    if expected not in bootstrap:
        raise ValueError("Unexpected Godot native plugin bootstrap")
    bootstrap = "void hole_feast_services_initialize();\nvoid hole_feast_services_deinitialize();\n" + bootstrap
    bootstrap = bootstrap.replace(expected, "void godot_apple_embedded_plugins_initialize() {\n    hole_feast_services_initialize();\n}")
    bootstrap = bootstrap.replace("void godot_apple_embedded_plugins_deinitialize() {\n}",
                                  "void godot_apple_embedded_plugins_deinitialize() {\n    hole_feast_services_deinitialize();\n}")
    info_path = exported / "SinkCity/SinkCity-Info.plist"
    info = plistlib.loads(info_path.read_bytes())
    info.update({"GADApplicationIdentifier": app_id, "HoleFeastRewardedUnit": unit,
                 "HoleFeastTestAds": test_ads,
                 "SKAdNetworkItems": [{"SKAdNetworkIdentifier": identifier + ".skadnetwork"}
                                      for identifier in SKAD_NETWORK_IDS]})
    info_path.write_bytes(plistlib.dumps(info, sort_keys=False))
    project.write_text(text); dummy.write_text(bootstrap)
    receipt = {"test_ads": test_ads, "uses_production_ad_identifiers": not test_ads,
               "skadnetwork_identifiers": [identifier + ".skadnetwork" for identifier in SKAD_NETWORK_IDS],
               "dependency_sha256": PINS, "vendor_privacy_manifests": manifests,
               "adapter_sha256": {p.name: sha(p) for p in sorted((ROOT / "native/ios").glob("*")) if p.is_file()},
               "configured_project_sha256": sha(project), "sdk_versions": {"GoogleMobileAds": "13.11.0", "UserMessagingPlatform": "3.1.0"},
               "purchase_protocol": "StoreKit 2 verified consumables, finish after persisted wallet acknowledgement"}
    (exported / "native-services.json").write_text(json.dumps(receipt, indent=2) + "\n")
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--export", required=True, type=Path)
    parser.add_argument("--dependencies", required=True, type=Path)
    parser.add_argument("--test-ads", action="store_true")
    parser.add_argument("--admob-app-id")
    parser.add_argument("--admob-rewarded-unit")
    args = parser.parse_args()
    if args.test_ads and (args.admob_app_id or args.admob_rewarded_unit):
        parser.error("Test mode uses only Google's sample IDs")
    if not args.test_ads and (not args.admob_app_id or not args.admob_rewarded_unit):
        parser.error("Production mode requires configured real app and rewarded unit IDs")
    result = configure(args.export, args.dependencies,
                       TEST_APP if args.test_ads else args.admob_app_id,
                       TEST_REWARDED if args.test_ads else args.admob_rewarded_unit, args.test_ads)
    print(json.dumps({"test_ads": result["test_ads"], "sdk_versions": result["sdk_versions"]}))


if __name__ == "__main__":
    main()
