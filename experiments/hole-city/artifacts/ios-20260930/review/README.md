# Independent iOS preparation review

**PASS for unbuilt physical-device Xcode project preparation**, with the
simulator limitation below. This is not signing, build, installation, upload,
store approval or iPhone performance acceptance.

Reviewed `tools/prepare_ios_project.py` SHA-256
`7cc927ef412accd05f0e7af2fc5dca23fe049c44d95369a883a88f5765a05a4e`
and the successful `build/ios-preparation-20260930-03/` output. The helper confines
writes to a new local build directory, copies rather than links source files,
rejects source symlinks, checks the standard template/version, and verifies the
original release inputs. Its strict export error handling retained both failed
attempts. The successful snapshot adds only the required mobile texture import
setting to the copied project settings and creates a separate native preset/icon.
No archive or IPA exists; project-only mode does not establish a signed app.

Independent checks verified:

- All **791** original Web release inputs still match the exact release receipt.
  All **752** originally copied files still match their source hashes; only the
  snapshot's `project.godot` differs, by the expected ETC2/ASTC import setting.
- All **47** exported file hashes match the preparation receipt. The genuine
  PCK is **10,555,176 bytes**, SHA-256
  `cee0c5f49200859f4fc023b5d966111894e81219aade2f1d52b15e4784f7e2c6`.
- A separate desktop-headless, test-mode resource probe loaded **315** resources
  directly from that PCK, including the main scene, scripts, imported models,
  textures, shaders, font and 88-second music. **Eight** raw data/license files
  match the snapshot. It instantiated no game scene and played no audio.
  The only engine diagnostic was the already identified macOS certificate-store
  warning; no unexpected errors occurred.
- The one target has Debug/Release configurations using the verified paid team
  and local draft `io.github.dotafs2.sinkcity`, version/build `0.11.1`/`1`, iPhone
  family and iOS 15.0 minimum. The ID remains unregistered. Both PCK and privacy
  manifest are in the actual Resources build phase; there are no shell-script
  phases. The dylibs directory contains only the template's empty marker.
- All **16** generated icon references resolve to correctly sized opaque PNGs,
  including the 1024-pixel icon. The plist specifies portrait; entitlements are
  empty. Privacy output declares no tracking and contains the selected local
  file-timestamp (`C617.1`), boot-time (`35F9.1`) and disk-space (`E174.1`) reasons.
  Their selection matches the [Godot 4.7.2 exporter](https://github.com/godotengine/godot/blob/4.7.2-stable/editor/export/editor_export_platform_apple_embedded.cpp).

## Actual remaining limitation

`lipo -archs` independently confirms **arm64** for both device engine and device
MoltenVK libraries. However, the simulator engine library contains **x86_64 only**
while its XCFramework metadata advertises arm64 and x86_64. Do not claim native
Apple Silicon simulator compatibility. A corrected matching official template
or source build is needed before accepting that target. The device library is
present, but its native linking and execution still need testing.

The official template contains empty camera/photo/microphone purpose strings.
The camera module and microphone input are disabled; inspect unused keys and
the actual final privacy report before store submission. Generated reason codes
are not certification of future SDK behavior. Native accessible credits,
privacy/support details, eligible Xcode/SDK, signing and real device acceptance
remain open. The template provenance correctly states that member/inner ZIP
CRCs were verified using official HTTPS ranges, while the complete template
archive SHA was not verified.

The parent README's explicit project-only and simulator limitations agree with
these observations (reviewed SHA
`4bb27b64dce95c00ad64c4ee377044c2dbffe7356ad864c7b676638ea3a25749`).
No further project-preparation blocker was found. This reviewer did not access
accounts, credentials or user UI, alter source/generated files, build/sign an
app, or broaden the regression suite. All owned probes exited.

Evidence: [metadata and hashes](review.json), [resource results](resources.json),
[strict engine log](resource.log), [resource probe](resource_probe.gd),
[read-only metadata audit](audit_native.py). The first metadata reader assumed
every icon entry had a scale; the universal 1024 entry legitimately omits it.
The reader was corrected to use its stated pixel size; no product file changed.
