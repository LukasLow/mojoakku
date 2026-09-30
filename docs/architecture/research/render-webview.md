# Research: window + system-webview + mobile stacks for `frame_native` / `frame_webview`

Scope: inform a MojoAkku plan for two namespaces — `frame_native` (OS window /
GPU surface) and `frame_webview` (embedded browser). Every claim carries a
source; unverified reasoning is marked `GUESS:`.

Date: 2026-09-29.

---

## 1. System webviews — the embedded browser per OS

| OS | Engine / component | Backing engine | Source |
|----|--------------------|----------------|--------|
| Windows | **WebView2** (Edge) | Chromium/Edge | <https://learn.microsoft.com/en-us/microsoft-edge/webview2/> |
| macOS / iOS | **WKWebView** | WebKit/Safari | <https://en.wikipedia.org/wiki/WebView> |
| Linux | **WebKitGTK** (a.k.a. webkit2gtk) | WebKit | <https://github.com/webview/webview> |
| Android | **android.webkit.WebView** | Chromium (via Android System WebView) | <https://en.wikipedia.org/wiki/WebView>, <https://developer.android.com/reference/android/webkit/WebView> |

The WebView article names exactly these four as "the prominent ones … bundled in
operating systems": Android System WebView (based on Chrome), Apple's WebView
(based on Safari), and Microsoft Edge WebView2. Source:
<https://en.wikipedia.org/wiki/WebView>.

**Are all C-callable?** No — they are *not uniformly* C-callable, and this is the
key negative result for Mojo:

- **Windows WebView2: yes, C API.** "The following programming environments are
  supported for WebView2: **Win32 C/C++**, .NET …" Source:
  <https://learn.microsoft.com/en-us/microsoft-edge/webview2/>.
- **macOS WKWebView: Objective-C/Swift frameworks**, not a flat C API. The
  `webview/webview` library reaches it through **Cocoa** (Obj-C), linking
  `-framework WebKit`. Source: <https://github.com/webview/webview> (platform
  table: "macOS — Cocoa, WebKit"; build flags `-framework WebKit`).
- **Linux WebKitGTK: C API via GTK** (`pkg-config gtk+-3.0 webkit2gtk-4.1`).
  Source: <https://github.com/webview/webview>.
- **Android WebView: Java/Kotlin API**, not C. `android.webkit.WebView` is an
  Android SDK class (<https://developer.android.com/reference/android/webkit/WebView>);
  native code would need JNI. Tauri's own Android plugin is Kotlin with
  `import android.webkit.WebView` (<https://v2.tauri.app/develop/plugins/develop-mobile/>),
  confirming there is no C entry point.

The practical proof that "one C API for all" is impossible: `webview/webview`
writes three separate backends and selects them at compile time with
`WEBVIEW_GTK` / `WEBVIEW_COCOA` / `WEBVIEW_EDGE`. Source:
<https://github.com/webview/webview> (Backend Selection section).

---

## 2. Tauri v2 — one codebase for desktop + Android + iOS

**Architecture.** Tauri is "a polyglot and generic toolkit … used for building
applications for desktop computers using a combination of Rust tools and HTML
rendered in a Webview." Source: <https://v2.tauri.app/concept/architecture/>.

Core crates (all from <https://v2.tauri.app/concept/architecture/>):

- `tauri` — the main crate; reads `tauri.conf.json`, holds runtimes/macros/API.
- `tauri-runtime` — "The glue layer between Tauri itself and lower-level webview
  libraries."
- `tauri-runtime-wry` — system-level WRY interactions.
- **TAO** — window creation: "Cross-platform application window creation library
  in Rust that supports all major platforms like Windows, macOS, Linux, iOS and
  Android … a fork of `winit`."
- **WRY** — "cross-platform WebView rendering library … determine[s] which
  webview is used."

**Backend language: Rust.** Tauri "directly uses WRY and TAO to do the heavy
lifting in making system calls to the OS … it is an application toolkit."
Source: <https://v2.tauri.app/concept/architecture/>.

**Native glue per platform.** Tauri's mobile plugins are written in **Kotlin
(Android)** and **Swift (iOS)**, with Rust as the shared core. Android classes
extend `app.tauri.plugin.Plugin`; iOS classes extend Swift `Plugin`. Source:
<https://v2.tauri.app/develop/plugins/develop-mobile/>. Cross-boundary calls use
**JNI on Android** and **C FFI on iOS** — the Tauri docs state: "using JNI on
Android and FFI on iOS allows plugins to call shared code". The iOS example uses
`@_silgen_name` to expose Swift functions to Rust's `extern "C"`. Source:
<https://v2.tauri.app/develop/plugins/develop-mobile/>.

Mobile toolchain requirements (Android Studio + SDK/NDK, Xcode + CocoaPods,
`rustup` targets per ABI). Source: <https://v2.tauri.app/start/prerequisites/>.

**IPC webview ↔ backend.** "Asynchronous Message Passing, where processes
exchange requests and responses serialized using some simple data
representation." Two primitives (<https://v2.tauri.app/concept/inter-process-communication/>):

- **Events** — fire-and-forget, one-way.
- **Commands** — an "FFI-like abstraction on top of IPC messages"; the JS
  `invoke` API calls Rust functions, using a **"JSON-RPC like protocol"** — all
  arguments/return must be JSON-serializable.

Because it is message passing (not real FFI), Tauri notes Commands "do not share
the same security pitfalls as real FFI interfaces do."
Source: <https://v2.tauri.app/concept/inter-process-communication/>.

**Size / consistency trade-off.** Tauri apps "are very small because they use
the OS's webview. They do not ship a runtime." Source:
<https://v2.tauri.app/concept/architecture/>.

---

## 3. Alternatives — system webview vs bundled Chromium

| Framework | Backend | Webview strategy | Source |
|-----------|---------|------------------|--------|
| **Tauri** | Rust | System webview (WebView2/WKWebView/WebKitGTK) | <https://v2.tauri.app/concept/architecture/> |
| **Wails** | Go | System webview — "Uses native rendering engines - *no embedded browser*!" | <https://github.com/wailsapp/wails> |
| **Neutralinojs** | C++ core + JS | System webview — "doesn't bundle Chromium and uses the existing web browser library in the operating system (Eg: gtk-webkit2)" | <https://github.com/neutralinojs/neutralinojs> |
| **Electron** | Node.js | Bundled Chromium — "By embedding **Chromium** and **Node.js** into its binary" | <https://www.electronjs.org/docs/latest/> |
| **Capacitor** | Web + native plugins | Mobile system WebView container ("Web Native apps … native container approach") | <https://capacitorjs.com/docs> |

**Neutralino's IPC detail** (useful model): "implements a WebSocket connection
for native operations and embeds a static web server to serve the web content."
Source: <https://github.com/neutralinojs/neutralinojs>.

**Wails IPC detail:** injects `/wails/ipc.js` + `/wails/runtime.js` into the
served HTML to install bindings. Source:
<https://wails.io/docs/guides/frontend/>.

### System webview vs bundled Chromium — trade-offs

| Axis | System webview (Tauri/Wails/Neutralino) | Bundled Chromium (Electron) |
|------|------------------------------------------|-----------------------------|
| **Size** | Tiny; "very small because they use the OS's webview" (<https://v2.tauri.app/concept/architecture/>) | Large; Chromium+Node embedded in every app (<https://www.electronjs.org/docs/latest/>) |
| **Consistency** | Depends on OS engine + version → version fragmentation | One pinned Chromium for all platforms |
| **Updates** | OS/vendor updates the engine (WebView2 "Evergreen") | App must ship engine updates |
| **Distribution** | Windows: WebView2 runtime needed pre-Win11 (<https://github.com/webview/webview>) | Self-contained |
| **Backend language** | Rust / Go / JS | JS (Node.js) |

WebView2 offers both "Evergreen distribution" (auto-updated Chromium) and
"Fixed Version distribution" (package specific Chromium bits).
Source: <https://learn.microsoft.com/en-us/microsoft-edge/webview2/>.

`GUESS:` On Linux the system-webview approach also drags in GTK as a runtime
dependency (`libgtk-4-1`, `libwebkitgtk-6.0-4`, per the webview README
<https://github.com/webview/webview>), so "lightweight" is less true there than
on Windows/macOS.

---

## 4. Raw GPU alternative (no webview)

**How you build a native app with its own renderer.** You need (a) a window +
input layer and (b) a graphics backend. The dominant portable graphics library
is **wgpu**, which "run[s] natively on Vulkan, Metal, DirectX 12, and OpenGL ES;
and browsers via WebAssembly on WebGPU and WebGL2." Source: <https://wgpu.rs/>.
wgpu has a C header, **wgpu-native** ("Official native WebGPU implementation",
<https://wgpu.rs/>), which is what a non-Rust language binds.

**Frame / event-loop shape.** The canonical loop is: *init window → while open →
gather input → update state → issue draw → present*. raylib's minimal example
shows exactly this:

```c
InitWindow(800, 450, "...");
while (!WindowShouldClose()) {
    BeginDrawing();
        ClearBackground(RAYWHITE);
        DrawText(...);
    EndDrawing();
}
CloseWindow();
```
Source: <https://github.com/raysan5/raylib>. `GUESS:` In wgpu terms this is
`instance → adapter → device → surface`, then per frame
`get_current_texture → command encoder → render pass → queue.submit → present`
— the wgpu-mojo example demonstrates this exact sequence
(<https://github.com/Hundo1018/wgpu-mojo>).

**Immediate mode vs retained mode.** Definition (source:
<https://en.wikipedia.org/wiki/Immediate_mode_(computer_graphics)>):

- **Immediate mode**: "the client calls directly cause rendering … the data to
  describe rendering primitives is inserted frame by frame directly from the
  client … without the use of extensive indirection." The scene lives in client
  memory; the app re-issues all draw commands every frame.
- **Retained mode**: the alternative; "historically … the dominant style in GUI
  libraries"; the library keeps the object model.

Immediate-mode GUIs call a draw/query function every frame instead of creating a
widget once — e.g. `DoButton()` vs `CreateButton()`. Prominent implementations:
**Dear ImGui** (C++), **Clay** (C), **Nuklear** (C). Source:
<https://en.wikipedia.org/wiki/Immediate_mode_(computer_graphics)>.

**egui** is the Rust immediate-mode reference: "In a retained GUI you create a
button, add it to some UI and install some on-click handler (callback) … in
immediate mode you show the button and interact with it immediately, and you do
so every frame (e.g. 60 times per second)." Advantages: simpler app code, no
callbacks, no GUI-state desync. Disadvantages: **layout is harder** (to center a
window you must know its size, but layout is what determines size → first-frame
jitter, worked around by re-running a pass with `Context::request_discard`), and
CPU cost from full re-layout each frame (egui ~1–2 ms/frame). Source:
<https://github.com/emilk/egui>. egui's native backend is **egui-wgpu** (wgpu) or
**egui_glow** (OpenGL); framework `eframe` supports Web/Linux/Mac/Windows/
Android. Source: <https://github.com/emilk/egui>.

**Skia:** not directly sourced in this pass — marked `GUESS:` Skia is a
2D retained-ish drawing library used by Flutter/Chrome, C-callable via its C API
(`skia_c`); treat as a candidate, needs a dedicated source before planning.

---

## 5. Mobile without a webview — a *native* Android/iOS UI

**Android — purely native is possible.** Android's **NativeActivity** allows "a
purely native application, with no Java source code", using the
**`native_app_glue`** helper library. Source:
<https://developer.android.com/ndk/samples/sample_na>,
<https://developer.android.com/reference/games/game-activity/group/android-native-app-glue>.
`native_app_glue` marshals the activity lifecycle (`APP_CMD_*`) and an
`AInputQueue` of input events on a separate thread. Sources:
<https://android.googlesource.com/platform/ndk/+/master/sources/android/native_app_glue/android_native_app_glue.h>,
<https://deepwiki.com/android/ndk-samples/4.1-basic-native-activity>.

But the native path is not glue-free — the NDK samples repo states: "In practice
most apps, even games which are predominantly native code, will need to call
some Java APIs or customize their app's activity further."
Source: <https://github.com/android/ndk-samples/tree/main/native-activity>.

**iOS — native needs a UIKit delegate.** `GUESS:` For a non-webview iOS UI you
must create a `UIWindow` and a `UIApplicationDelegate`/`UIViewController` in
Objective-C/Swift, then render into a `CAMetalLayer` (Metal) that your graphics
layer draws to; there is no C-only path. This follows from Apple's platform
frameworks being Obj-C (see §1 WKWebView) and from Tauri's iOS integration being
Swift (`@_silgen_name` FFI bridge, <https://v2.tauri.app/develop/plugins/develop-mobile/>).
Needs an Apple-source verification before implementation.

**What SDL / raylib do for you.** They package exactly this platform glue behind
one C API. SDL is "a cross-platform library designed to make it easy to write
multi-media software" (zlib licence), source:
<https://github.com/libsdl-org/SDL>; the repo ships `android-project/`,
`Xcode/`, `CMakeLists.txt` for platform glue. raylib "supports: **Windows, Linux,
MacOS, RPI, Android, HTML5**", is "Written in plain C code (C99)", "**NO
external dependencies**", and has a single-window OpenGL model. Source:
<https://github.com/raysan5/raylib>. `GUESS:` Both achieve portability by
embedding the same JNI/Activity (Android) and Obj-C delegate (iOS) glue that a
Mojo layer would otherwise have to write itself — i.e. the glue is unavoidable,
SDL/raylib merely hide it.

**How much glue is unavoidable?** `GUESS:` For a non-webview mobile UI, at least:
an Android Activity/NativeActivity entry + JNI for lifecycle/input, and an iOS
`UIApplicationDelegate` + a Metal drawable. The windowing library owns it; a
language binding calls into it. This is the layer TAO (Tauri) and SDL each
implement independently.

---

## 6. Licences and constraints

**System webview approach.** You do not ship the engine, so you inherit its
distribution terms rather than bundling code.

- **Windows WebView2**: free Microsoft control, distributed as "Evergreen
  Runtime" or "Fixed Version"; source
  <https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution>.
  `GUESS:` The runtime itself is distributable with apps per Microsoft's terms;
  verify the WebView2 SDK licence text before shipping.
- **macOS/iOS WKWebView**: part of the OS; no bundling.
- **Linux WebKitGTK**: WebKit "is open source software with portions licensed
  under the LGPL and BSD licenses" — source <https://webkit.org/licensing-webkit/>.
  LGPL is the constraint to watch: dynamic linking against the system library is
  the normal, safe route. Source: <https://docs.webkit.org/Other/Licensing.html>.

**Bundled Chromium (Electron).** Chromium is under a BSD-3-Clause-style licence:
"a permissive license similar to the BSD 2-Clause License, but with a 3rd clause
that prohibits others from using the name of the copyright holder … to promote
derived products." Source:
<https://github.com/chromium/chromium/blob/main/LICENSE>. Electron redistributes
it under `LICENSE.chromium`
(<https://github.com/electron/electron/blob/main/chromium_src/LICENSE.chromium>).
`GUESS:` Permissive, so bundling is licence-safe; the costs are size and the
obligation to ship Chromium security updates yourself.

**iOS app-store constraint (the big one).** Apple's App Review Guidelines,
**§2.5.6**, state: "Apps that browse the web must use the appropriate **WebKit
framework and WebKit JavaScript**. You may apply for an entitlement to use an
alternative web browser engine in your app. [EU and Japan]." Source:
<https://developer.apple.com/app-store/review/guidelines/> (section 2.5
Software Requirements, 2.5.6).

Consequences (facts): on iOS, a `frame_webview` **must** use WKWebView for
ordinary apps; bundling Chromium/Gecko is only possible via special entitlements
limited to the **EU and Japan**. Source: same page, and
<https://developer.apple.com/support/alternative-browser-engines/> (cited by the
guideline). `GUESS:` This makes "system webview" not merely lighter but the only
compliant default on iOS — the opposite choice (bundled engine) is an
App-Store-rejection risk outside the EU/Japan.

---

## 7. For MojoAkku — what is realistically bindable from Mojo

**Mojo's FFI capability (from the `mojov1` buch, page `interop/calling-c`):**

- Mojo can call C directly: "Mojo emits a direct native call, with no translation
  layer or extra runtime overhead." Source: <https://mojolang.org/docs/manual/c-ffi/>.
- Two mechanisms: `external_call["name", RetType](...)` (symbol resolved at build
  time) and `OwnedDLHandle(path).get_function[RetType]("name")` (runtime
  `dlopen`). Source: `mojov1/interop/calling-c`, and
  <https://mojolang.org/docs/manual/c-ffi/>.
- **Callbacks work**: a Mojo function marked `abi("C")` and `thin` can be passed
  as a C function pointer (the `qsort` example). Source:
  `mojov1/interop/calling-c` → <https://mojolang.org/docs/manual/c-ffi/>.
- **Structs work**: "C-compatible types are ordinary structs … conform to
  `RegisterPassable` … Field order matters." Source: same page.
- Platform library names are chosen at compile time with `platform_map`
  (e.g. `linux="libm.so.6", macos="libm.dylib"`). Source: same page.
- **Important constraints**: return types must be `RegisterPassable` — "A C
  function that returns a big struct by value isn't callable directly." A wrong
  declaration "is not a compile error — it is a wrong answer, often a
  plausible-looking one." Source: same page.

**Mojo platform support** (matters enormously here): "Mojo runs on Mac, Linux,
and Windows (with WSL)" — **Windows only through WSL**, macOS is Apple-silicon
only (Sequoia 15+), Linux glibc 2.34+. Source: `mojov1/intro/supported-platforms`
→ <https://mojolang.org/docs/requirements/>. **There is no native Windows
target, no iOS target, no Android target documented.**

**Existing precedent:** `wgpu-mojo` (Apache-2.0) already binds **wgpu-native** +
**GLFW** from pure Mojo, with RAII GPU objects and a windowed `RenderCanvas`
(`examples/triangle_window.mojo`), plus GLFW keyboard/mouse polling. It pins
wgpu-native v29.0.0.0 and notes "macOS is compute-only today … there is no
`CAMetalLayer` path yet". Source: <https://github.com/Hundo1018/wgpu-mojo>.
Listed as the Mojo binding on the official wgpu site: <https://wgpu.rs/>.

### What each namespace would actually have to implement

**`frame_native` (realistic now):**

- A **C-ABI binding to one portable window+GPU library**, not a hand-written
  window per OS. Candidates by licence/FFI fit:
  - **SDL3** (zlib, <https://github.com/libsdl-org/SDL>) — plain C, own platform
    glue for Android/iOS/desktop, audio+input+window. Best single target.
  - **GLFW** — already proven from Mojo via wgpu-mojo
    (<https://github.com/Hundo1018/wgpu-mojo>).
  - **raylib** (zlib, <https://github.com/raysan5/raylib>) — C, OpenGL,
    "no external dependencies", mobile+WASM support.
  - **wgpu-native** for the GPU layer (<https://wgpu.rs/>).
- What it must implement: window create/destroy, an event poll + dispatch loop
  (`frame` event loop), input structs, a swapchain/surface abstraction, and
  `abi("C")` callback trampolines. All are C APIs → bindable per the C-FFI page.
- What it **cannot** do from Mojo alone: run on native Windows, iOS or Android
  until Mojo itself ships those targets (`mojov1/intro/supported-platforms`).
  On those platforms Mojo code can only be a guest inside a host process.

**`frame_webview` (much harder):**

- **Windows**: bind WebView2's C API directly (documented Win32 C/C++,
  §1). Feasible in principle, but only on WSL today — `GUESS:` WebView2 needs a
  real Win32 process, so this is blocked until Mojo has a native Windows target.
- **Linux**: bind **WebKitGTK via GTK4** C API (`pkg-config gtk4 webkitgtk-6.0`,
  §1). The most plausible first webview target on a supported Mojo platform.
- **macOS**: WKWebView is Objective-C; Mojo has no Obj-C bridge documented in
  `mojov1` (only C FFI and Python interop). You would need a small **Obj-C/C
  shim library** exposing a C façade, then bind *that*. `GUESS:` Obj-C message
  dispatch is not C ABI, so a shim is unavoidable.
- **iOS/Android**: WebView is an Obj-C/Swift (iOS) and Java/Kotlin (Android)
  class — same shim problem, plus no Mojo target. Blocked.
- The JS↔Mojo IPC that Tauri gets from WRY you would have to build: a WebSocket
  or native message bridge + a JSON-RPC-ish protocol, mirroring Tauri
  (<https://v2.tauri.app/concept/inter-process-communication/>). `frame_webview`
  is therefore mostly *glue + IPC design*, not browser work.

**Is the Tauri-style "one codebase, system webview, mobile" reachable?**
**No — not today, and not from pure Mojo.** Reasons grounded in sources:
1. It requires per-platform native glue in Kotlin/Swift/Obj-C, which Tauri
   writes in those languages (<https://v2.tauri.app/develop/plugins/develop-mobile/>),
   not from the backend language.
2. Mojo has no native Windows, iOS or Android target
   (`mojov1/intro/supported-platforms`).
3. WKWebView/Android WebView have no C API (§1); each needs an Obj-C/JNI shim.
4. Mojo has no documented Obj-C or JNI bridge — only C FFI and Python interop
   (`mojov1/interop/calling-c`).
`GUESS:` The reachable long-term shape is Tauri-like *architecture* (Mojo core +
per-platform C-shim libraries + message-passing IPC), but the mobile and macOS
parts must live in host-language shim libraries that Mojo calls, exactly as WRY
does. "One codebase" would mean one *Mojo* codebase plus several thin,
hand-written native shims.

---

## 8. Recommendation

### Minimum viable first `frame_` target

**`frame_native` first, on a C window+input library, with wgpu-native for the
GPU surface — and no webview at all in v1.**

- Bind **SDL3** (zlib, C99-ish, own desktop+Android+iOS glue,
  <https://github.com/libsdl-org/SDL>) *or* **GLFW** (already proven from Mojo by
  wgpu-mojo, <https://github.com/Hundo1018/wgpu-mojo>) as the window/event layer.
- Bind **wgpu-native** for rendering: portable across Vulkan/Metal/DX12/GLES
  (<https://wgpu.rs/>), with an existing Mojo binding to study
  (<https://github.com/Hundo1018/wgpu-mojo>).
- Deliver: `frame_native` = window + event loop + surface + input, one file per
  API under `akku/frame_native/`, per the MojoAkku layout.
- This is bindable **today** on Linux and macOS (Apple silicon) only, because
  those are Mojo's supported targets (`mojov1/intro/supported-platforms`) and
  both SDL3 and wgpu-native/GLFW are C-callable (C-FFI page).

Why not webview first: every webview target needs either a C API that only
exists on Windows/Linux (WebView2/WebKitGTK), or an Obj-C/JNI shim for
macOS/iOS/Android — strictly more glue and blocked on unsupported Mojo targets.

### Long-term multi-platform shape

1. **`frame_native` (C window + wgpu)** — ship first; extend as Mojo gains
   targets. Optional: an immediate-mode UI drawn on top (Dear ImGui/Nuklear are
   C and thus bindable; egui needs Rust, <https://github.com/emilk/egui>,
   <https://en.wikipedia.org/wiki/Immediate_mode_(computer_graphics)>).
2. **`frame_webview` on Linux (WebKitGTK C API)** — second step, pure C, on a
   supported Mojo platform (<https://github.com/webview/webview> shows the
   backend split to emulate). Reuse `webview/webview`'s MIT C API shape as the
   design template rather than inventing one.
3. **macOS webview via a small Obj-C/C shim** — third step; the shim exposes a C
   façade that Mojo binds through `external_call`/`OwnedDLHandle`.
4. **Mobile (Android/iOS) only via host-language shims + JNI/Obj-C**, and only
   once Mojo can be compiled into those processes — mirroring Tauri's Kotlin/
   Swift plugin layer (<https://v2.tauri.app/develop/plugins/develop-mobile/>).
   A pure-Mojo Tauri equivalent is not reachable (§7).
5. **IPC layer** shared by webview/native features: message passing over a
   WebSocket or native bridge, JSON-serializable, with permissions — the proven
   Tauri/Neutralino model (`<https://v2.tauri.app/concept/inter-process-communication/>`,
   <https://github.com/neutralinojs/neutralinojs>).

### Licence note for MojoAkku

SDL3, raylib, webview/webview, wgpu-native are permissive (zlib/MIT/Apache) —
safe to bind and ship. If the Linux webview path links **WebKitGTK**, treat it as
LGPL and link dynamically against the system library, never statically
(<https://webkit.org/licensing-webkit/>). On iOS the App Store forces WKWebView
for web browsing (guideline §2.5.6, <https://developer.apple.com/app-store/review/guidelines/>).

---

## Sources (consolidated)

- WebView overview: <https://en.wikipedia.org/wiki/WebView>
- WebView2: <https://learn.microsoft.com/en-us/microsoft-edge/webview2/>,
  distribution: <https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution>
- Android WebView API: <https://developer.android.com/reference/android/webkit/WebView>
- webview/webview (C/C++, backend split, licences):
  <https://github.com/webview/webview>
- Tauri architecture: <https://v2.tauri.app/concept/architecture/>
- Tauri IPC: <https://v2.tauri.app/concept/inter-process-communication/>
- Tauri mobile plugins (Kotlin/Swift, JNI/FFI):
  <https://v2.tauri.app/develop/plugins/develop-mobile/>
- Tauri prerequisites: <https://v2.tauri.app/start/prerequisites/>
- Tauri app size: <https://v2.tauri.app/concept/size/>
- Wails: <https://github.com/wailsapp/wails>, frontend/IPC:
  <https://wails.io/docs/guides/frontend/>
- Neutralinojs: <https://github.com/neutralinojs/neutralinojs>
- Electron: <https://www.electronjs.org/docs/latest/>
- Capacitor: <https://capacitorjs.com/docs>
- wgpu: <https://wgpu.rs/>
- wgpu-mojo: <https://github.com/Hundo1018/wgpu-mojo>
- SDL: <https://github.com/libsdl-org/SDL>
- raylib: <https://github.com/raysan5/raylib>
- egui (immediate mode): <https://github.com/emilk/egui>
- Immediate mode (graphics): <https://en.wikipedia.org/wiki/Immediate_mode_(computer_graphics)>
- Android NativeActivity: <https://developer.android.com/ndk/samples/sample_na>,
  native_app_glue: <https://developer.android.com/reference/games/game-activity/group/android-native-app-glue>
- iOS App Review Guidelines §2.5.6:
  <https://developer.apple.com/app-store/review/guidelines/>
- WebKit licensing: <https://webkit.org/licensing-webkit/>,
  <https://docs.webkit.org/Other/Licensing.html>
- Chromium licence: <https://github.com/chromium/chromium/blob/main/LICENSE>
- Mojo C FFI: <https://mojolang.org/docs/manual/c-ffi/> and buch
  `mojov1/interop/calling-c`
- Mojo supported platforms: <https://mojolang.org/docs/requirements/> and buch
  `mojov1/intro/supported-platforms`
