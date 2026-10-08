# Independent review: private build cache

Status: PASS for workspace containment and the bounded runtime-source comparison. Reviewer: expand_skin_catalog; configuration author: root.

The self-contained marker is a 68-byte plain-text file beside the private bundled Godot application, at .build/godot-standard/_sc_. Its contents describe a workspace-local cache; it is not executable game code. The marker, bundled executable, generated editor documentation cache and editor settings file all resolve inside this game's .build/godot-standard directory. None of the inspected leaf paths is a symlink, and resolving the full paths does not escape the workspace. The game-specific .gitignore excludes .build/, so the application and generated editor data remain private build artifacts.

The retained headless editor-import log contains no unexpected error. It shows the existing macOS certificate-store diagnostic, followed by completed filesystem initialization and editor-layout loading. The documentation cache and editor settings were created under the private editor_data directory, rather than requiring access to global editor locations. The reviewer did not launch an editor window, gameplay, or another import process.

All 38 files in the pre-import CPU evidence's source_sha256 map still match their recorded hashes. This bounded comparison covers the fidelity runtime scripts and shaders, project.godot and the CPU fixture. It demonstrates that those runtime/configuration files were not changed by the cache correction. It is not a full repository or player-save before/after manifest: the failed export did not persist its entire frozen hash set, and no historical save checksum was available. That missing evidence is not reconstructed or overstated.

The current release error detector still rejects cache creation failure, editor-settings save failure, script parse errors, global cache open failure and generic permission denial. All five independent rejection probes pass. No cache/settings warning was added to the allowlist. The fresh release run freezes and rechecks its inputs before publication.

The correction changes the private build executable's editor-data location. It does not edit the web game's save code. Reviewed runtime code still skips normal progress loading under --test and uses an empty test save path unless a test explicitly supplies an isolated path. The reported import was an editor import, not a gameplay session. This review did not access or modify any real player save and does not claim a historical byte-for-byte save comparison.

Evidence: artifacts/fixes-20260928/reviews/build-cache.json, including resolved paths, prior-manifest comparison, import-log hash and strict-error probes. The independent review made only documentation/evidence writes and no runtime, toolchain or permission changes.
