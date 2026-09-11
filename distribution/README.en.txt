InfiniteAincrad 0.0.1 technical preview — Windows x64

Extract the entire folder and open InfiniteAincrad.exe. Keep the PCK and data folder.
No Godot editor, .NET SDK, Python or API key is required to play.

WASD: move. Click: capture mouse. Escape: release mouse. F8: diagnostics.
Follow the resident to the well and wait for her request. Approach the well and
press E to provide rope and a bucket. Watch her draw and drink water. Close the
window and reopen it to check that the result persists. You may withhold help;
the unmet request remains. In-game instructions currently use Chinese.

Save location:
%APPDATA%\Godot\app_userdata\InfiniteAincrad - Starting Town Street\technical-preview\world.json
Back up after closing the game. Damaged saves report an error; they are not reset.
The preview has its own save location. Run only one writer for a given save.

This is a labelled offline fixture with placeholder character geometry and Luna's
well event. No live model is called. Separate two-resident live-model evidence is
available in the source repository. Windows x64 and a Vulkan-capable GPU are the
current target. For a GPU startup issue, try from this folder:
  .\InfiniteAincrad.exe --rendering-method gl_compatibility
This alternative renderer still requires testing on your hardware.
Logs are in the logs directory alongside the technical-preview save directory.

Report Windows/GPU, launch result, where you got stuck and what survived restart.
Do not include secrets or private saves. Identify the build using build-info.json.

https://github.com/dotafs2/InfiniteAincrad
Local prerelease review artifact; the original project's redistribution license
is still pending. Existing third-party licenses are in licenses/ and
THIRD_PARTY_NOTICES.md.
