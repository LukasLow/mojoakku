# Rust rendering stack — research for MojoAkku `frame_*` / `gpu_*` / `ui_*`

Question: how does the Rust ecosystem layer windowing, GPU rendering, webview and
mobile? Which layering is proven, and what is reachable from Mojo's C-FFI?

Every claim below carries a source (URL or repo/path:line). Guesses are marked
`GUESS:`.

---

## 1. Windowing — `winit` vs `tao`

### What layer they occupy

`winit` is deliberately the bottom layer of a stack:

> "Winit is a window creation and management library. It can create windows and
> lets you handle events (for example: the window being resized, a key being
> pressed, a mouse movement, etc.) produced by the window.
> Winit is designed to be a low-level brick in a hierarchy of libraries.
> Consequently, in order to show something on the window you need to use the
> platform-specific getters provided by winit, or another library."
> — <https://github.com/rust-windowing/winit> (README)

`tao` is a fork of winit, maintained for Tauri, differing mainly in the Linux
backend:

> "Cross-platform application window creation library in Rust that supports all
> major platforms like Windows, macOS, Linux, iOS and Android. Built for you,
> maintained for Tauri."
> "This is a fork of winit which replaces Linux's port to Gtk."
> — <https://github.com/tauri-apps/tao> (README)

So both occupy the **same layer**: OS window + event loop + input. They are
interchangeable for the frame/window role; tao exists because Tauri needed
GTK menus/tray and a GTK Linux port (`tao/README.md`: Linux needs `libgtk-3-dev`;
Android uses `ndk-rs` and `ndk_glue::main`).

### What they abstract

- **Event loop + OS window + input.** `EventLoop` "Provides a way to retrieve
  events from the system and from the windows that were registered to the events
  loop. … Calling `EventLoop::new` initializes everything that will be required
  to create windows."
  — <https://docs.rs/winit/latest/winit/event_loop/struct.EventLoop.html>
- Not `Send`/`Sync`; cross-thread wakeups go through `EventLoopProxy`.
  — same page.
- Key types/traits (winit 0.30):
  - `EventLoop<T>` / `EventLoopBuilder<T>` / `ActiveEventLoop` (window creation
    moved to `ActiveEventLoop::create_window` in 0.30; `EventLoop::create_window`
    is deprecated).
  - `ApplicationHandler<T>` trait: `resumed`, `window_event`, `about_to_wait`.
  - `Window`, `WindowAttributes`, `WindowId`, `WindowEvent`, `Event`.
  - Platform extension traits: `EventLoopExtAndroid::android_app()`,
    `EventLoopExtIOS::idiom()`, `EventLoopExtWayland`, `EventLoopExtX11`,
    `EventLoopExtWebSys`.
  — <https://docs.rs/winit/latest/winit/event_loop/struct.EventLoop.html>
- Supported platforms: Desktop (Windows, macOS, X11, Wayland, Redox/Orbital),
  Mobile (iOS, Android), Web.
  — <https://github.com/rust-windowing/winit/blob/master/FEATURES.md>

### What they do NOT do (critical for the design)

> "Winit ***does not*** directly expose functionality for drawing inside windows
> or creating native menus, but ***does*** commit to providing APIs that
> higher-level crates can use to implement that functionality."
> — <https://github.com/rust-windowing/winit/blob/master/FEATURES.md> ("Winit Scope")

No rendering, no GPU, no widgets, no webview. It hands out platform window
handles (via `raw-window-handle`) for a GPU/other library to consume.

---

## 2. GPU abstraction — `wgpu`

> "`wgpu` is a cross-platform, safe, pure-Rust graphics API. It runs natively on
> Vulkan, Metal, D3D12, and OpenGL; and on top of WebGL2 and WebGPU on wasm.
> The API is based on the WebGPU standard, but is a fully native Rust library."
> — <https://github.com/gfx-rs/wgpu> (README)

### Key concepts

- `Instance` → `Adapter` → `Device`; `Queue` for submissions; `Surface` for
  presentation; `ShaderModule`, `Pipeline` (`RenderPipeline`/`ComputePipeline`),
  `Buffer`, `Texture`.
- `Surface` is the window bridge:

  > "A `Surface` represents a platform-specific surface (e.g. a window) onto
  > which rendered images may be presented. A `Surface` may be created with the
  > function `Instance::create_surface`."
  > `Surface::configure(device, config)` initialises presentation;
  > `Surface::get_current_texture()` retrieves the next frame; then
  > `Queue::submit(...)` and `Queue::present(...)`.
  > — <https://docs.rs/wgpu/latest/wgpu/struct.Surface.html>

### How it relates to winit — who owns the surface?

- wgpu does **not** own the window. `Surface<'window>` borrows it (lifetime in
  the type), and `wgpu` depends on `raw-window-handle ^0.6.2` to accept a window
  from any windowing library.
  — <https://docs.rs/wgpu/latest/wgpu/struct.Surface.html> (deps list)
- winit implements `HasWindowHandle` / `HasDisplayHandle` (raw-window-handle
  traits), so the **integration layer** (not wgpu, not winit) calls
  `instance.create_surface(window)` with the winit window. This exchange is the
  seam between the "frame" and "gpu" namespaces.
- On macOS the surface path hits AppKit objects that are main-thread-only
  (`NSScreen`/`NSWindow`), so `display_hdr_info` must be called on the main
  thread. — same docs page.

### The C entry point for other languages

> "This is a native WebGPU implementation in Rust, based on wgpu-core. The
> bindings are based on the WebGPU-native header found at
> `ffi/webgpu-headers/webgpu.h` and wgpu-native specific items in `ffi/wgpu.h`."
> — <https://github.com/gfx-rs/wgpu-native> (README)

`wgpu-native` is the C ABI layer; the README explicitly lists
[`wgpu-mojo`](https://github.com/Hundo1018/wgpu-mojo) as the Mojo binding
(see §6). License: MIT OR Apache-2.0 (`wgpu-native/LICENSE.MIT`, "Copyright (c)
2021 The gfx-rs developers").

---

## 3. Webview shells — `tauri` and `wails`

### Tauri: tao (window) + wry (webview) + core (IPC)

From the official architecture doc:

> "Tauri is not a lightweight kernel wrapper…instead it directly uses WRY and TAO
> to do the heavy-lifting in making system calls to the OS."
> — <https://github.com/tauri-apps/tauri/blob/dev/ARCHITECTURE.md>

Moving parts:

| Part | Role | Source |
|---|---|---|
| `tauri` | main crate, reads `tauri.conf.json` at compile time, script injection, API host | ARCHITECTURE.md |
| `tauri-runtime` | "glue layer between tauri itself and lower level webview libraries" | ARCHITECTURE.md |
| `tauri-runtime-wry` | `tauri-runtime` implementation for WRY (printing, monitors, windowing) | ARCHITECTURE.md |
| `tauri-build` / `tauri-codegen` / `tauri-macros` | build-time macros, embed+hash assets, parse config, generate command handlers | ARCHITECTURE.md |
| `@tauri-apps/api` (TS→JS) | "uses the message passing of webviews to their hosts" | ARCHITECTURE.md |
| `tauri-cli` / `create-tauri-app` / bundler | dev server, `tauri dev`, `tauri build`, per-OS bundling | ARCHITECTURE.md |

WRY, the webview layer, and its backends:

> "Wry is a cross-platform WebView rendering library. The webview requires a
> running event loop and a window type that implements `HasWindowHandle`, or a
> gtk container widget…"
> Platform engines: **Linux** = WebKitGTK (needs GTK; `libwebkit2gtk-4.1-dev`);
> **macOS** = native WebKit; **Windows** = WebView2 (Microsoft Edge Chromium).
> — <https://github.com/tauri-apps/wry/blob/dev/README.md>

IPC model: JS calls into Rust via `invoke` from `@tauri-apps/api/core`; Tauri v2
replaced the v1 allowlist with a capability/permission system
(<https://v2.tauri.app/start/migrate/from-tauri-1/>). Dev tooling: `tauri dev`
starts the JS dev server + window with devtools; `tauri build` "Cross
compilation is not currently available" (ARCHITECTURE.md). System deps:
`webkit2gtk-4.1-dev` on Linux, WebView2 runtime + MSVC Build Tools on Windows
(<https://v2.tauri.app/start/prerequisites/>).

### Wails — same model, Go backend

> "it provides the ability to wrap both Go code and a web frontend into a single
> binary" … "Easily call Go methods from Javascript" … "Uses native rendering
> engines - _no embedded browser_!"
> — <https://github.com/wailsapp/wails> (README); License MIT
> (`wails/LICENSE`, "Copyright (c) 2018-Present Lea Anthony").

Same four moving parts: OS window + system webview + language backend + IPC
bridge + CLI/bundler. Wails v2/v3 (v3 beta).

### The reusable lesson

A webview shell is **not** a widget toolkit on top of a GPU. It is a *parallel
branch*: window (tao) → system webview (wry) → HTML/JS UI, with an IPC bridge to
the host language. It shares only the **window/event-loop** layer with the
wgpu/egui path.

---

## 4. Mobile (Android / iOS)

### Tauri v2

- Cargo must produce a shared library:
  `[lib] crate-type = ["staticlib", "cdylib", "rlib"]`; `main.rs` → `lib.rs`;
  `#[cfg_attr(mobile, tauri::mobile_entry_point)] pub fn run()`.
  — <https://v2.tauri.app/start/migrate/from-tauri-1/>
- Commands: `tauri android dev` / `tauri ios dev`, `--open` to use Android
  Studio / Xcode. iOS requires Xcode + CocoaPods; Android requires Android Studio
  + NDK, `ANDROID_HOME`/`NDK_HOME`, `rustup target add aarch64-linux-android …`.
  — <https://v2.tauri.app/start/prerequisites/> and <https://v2.tauri.app/develop/>
- On iOS Tauri "creates a build phase that executes the Tauri CLI to compile the
  Rust source as a library that is loaded at runtime." — <https://v2.tauri.app/develop/>

### winit / wry mobile plumbing

- winit supports iOS and Android; platform traits `EventLoopExtAndroid`,
  `EventLoopExtIOS` (<https://docs.rs/winit/latest/winit/event_loop/struct.EventLoop.html>).
- The Android glue is a separate crate. `android-activity`:

  > "provides a 'glue' layer for building native Rust applications on Android,
  > supporting multiple Activity base classes. It's comparable to
  > `android_native_app_glue.c`… load your crate as a `cdylib` library via the
  > `onCreate` method of your Android `Activity` class; run an `android_main`
  > function in a separate thread from the Java main thread and marshal events
  > (such as lifecycle events and input events) between Java and your native
  > thread."
  > — <https://github.com/rust-mobile/android-activity> (README)

  Two Activity base classes: `NativeActivity` (no Java/Kotlin needed, but **no
  built-in IME** → poor text input) and `GameActivity` (AppCompatActivity-based,
  IME support, but requires the AndroidX Gradle dependency). wry's Android path
  needs generated Kotlin (`WryActivity`, `WRY_ANDROID_PACKAGE`,
  `wry::android_setup`, `wry::android_binding!`) and recommends tao
  (<https://github.com/tauri-apps/wry/blob/dev/README.md>).

### What the pain actually is

> "At the end of the day, Android's application programming model is
> fundamentally based around a Java VM running Java/Kotlin code that can
> optionally call into native code (not the other way around)."
> — <https://github.com/rust-mobile/android-activity> (README)

> "It's not possible to subclass an Activity from Rust / JNI code alone."
> — same README

So the OS-specific entry point is: Java/Kotlin `Activity` (or AppDelegate on iOS)
→ loads a `cdylib` → calls a native `main` → native code polls events. The
`cdylib` + Gradle/Xcode packaging is the plumbing; the Activity/UIApplication
subclass is the platform-owned part.

---

## 5. UI toolkits — egui vs iced

### egui — immediate mode

> "egui … is a simple, fast, and highly portable **immediate mode** GUI library
> for Rust." … "**Pure immediate mode**: no callbacks"
> "egui itself doesn't know or care on what OS it is running or how to render
> things to the screen - that is the job of the egui integration."
> — <https://github.com/emilk/egui> (README)

Sits on **winit + wgpu** through `eframe`:

> "`eframe` … Uses `egui-winit` and `egui_glow` or `egui-wgpu`"
> Official integrations: `eframe`, `egui_glow` (OpenGL/glow),
> `egui-wgpu` (wgpu), `egui-winit` (winit).
> — same README

"egui is *not* a framework. egui is a library you call into" — same README.
License MIT OR Apache-2.0.

### iced — retained (Elm architecture)

> "A cross-platform GUI library for Rust focused on simplicity and type-safety.
> Inspired by Elm." … "Type-safe, reactive programming model" …
> "Modular ecosystem split into reusable parts: A renderer-agnostic native
> runtime… Two built-in renderers leveraging `wgpu` and `tiny-skia` …
> A windowing shell [`winit`]"
> — <https://github.com/iced-rs/iced> (README)

Elm/TEA means **retained** state: `State` + `Message` + `view()` + `update()`
(README). `iced_wgpu` supports Vulkan, Metal, DX12; `iced_tiny_skia` is the
software fallback. "Iced is currently experimental software." — README.

**Bottom line:** both are the *same* layer (widgets/UI), differing in paradigm
(immediate vs retained), and both sit on **winit (window) + wgpu (render)**.

---

## 6. What a Mojo port can reach — actual C libraries and licenses

Mojo's C-FFI (verified in the local `mojov1` buch, page `interop/calling-c`):

- `external_call["sym", RetType]` — link-time symbol, "Mojo emits a direct native
  call, with no translation layer" (<https://mojolang.org/docs/manual/c-ffi/>).
- `OwnedDLHandle` + `get_function[RetType]("sym")` — runtime `dlopen`; required
  because "`external_call()` cannot load dynamic libraries".
- `abi("C")` + `thin` callbacks for C-to-Mojo function pointers (the `qsort`
  example).
- C-compatible structs: `@fieldwise_init` + `RegisterPassable`, field order =
  memory layout. Return types must be `RegisterPassable` (larger structs go
  through a hidden pointer).
- `Optional[Pointer[T, MutUntrackedOrigin]]` for nullable C returns; `OpaquePointer`
  for `void*`.
- **This is sufficient for all the C libraries below**, but every signature is
  unchecked: "a wrong FFI declaration is not a compile error — it is a wrong
  answer."

| C library | Role | License | Source |
|---|---|---|---|
| **SDL2 / SDL3** | window + input + GL/Vulkan context; SDL3 adds `SDL_gpu` | **zlib** (SDL 2.0+; SDL 1.2 was LGPL) | <https://www.libsdl.org/license.php> |
| **GLFW** | window + context + surface + input (C99) | **zlib/libpng** | <https://www.glfw.org/license.html>, <https://github.com/glfw/glfw> |
| **raylib** | window + OpenGL + input + audio, deps vendored; **Android + HTML5 supported** | **zlib/libpng** | <https://github.com/raysan5/raylib> (README, LICENSE) |
| **wgpu-native** | raw GPU (Vulkan/Metal/DX12/GL) via `webgpu.h` + `wgpu.h` | **MIT OR Apache-2.0** | <https://github.com/gfx-rs/wgpu-native>, `wgpu-native/LICENSE.MIT` |
| **WebKitGTK** | Linux system webview (the wry Linux backend) | `GUESS:` LGPL-2.1+ for the GTK port (WebKit core is LGPL-2/BSD) — verify before shipping | <https://webkitgtk.org/> |
| **WebView2** | Windows system webview | `GUESS:` proprietary Microsoft; free redistributable Evergreen runtime, not OSS | <https://v2.tauri.app/start/prerequisites/> |
| **WKWebView** | macOS/iOS system webview | `GUESS:` proprietary Apple, part of the OS SDK | <https://github.com/tauri-apps/wry/blob/dev/README.md> |
| **SDL_gpu** (SDL3) | raw GPU abstraction (WebGPU-style, part of SDL3) | zlib (same SDL3 license) | <https://www.libsdl.org/license.php> |

**Mojo precedent already exists:** `wgpu-mojo` (Apache-2.0) binds `wgpu-native`
and ships a `RenderCanvas` that "wraps GLFW so the same device drives an
interactive surface" (<https://github.com/Hundo1018/wgpu-mojo>). It proves both
the GLFW-window + wgpu-native-surface path and the conda packaging route
(`pixi add wgpu-mojo`; pulls `wgpu-native` + `glfw` as conda deps).

**Mojo's own GPU stack is separate:** host-side dispatch (`DeviceContext`,
`DeviceBuffer`) ships only in the `max` package; `wgpu-mojo` bridges at
stage boundaries with **host round trips, no zero-copy path** (README).

---

## 7. Evaluation of the proposed MojoAkku layering

Proposed:

```
gpu_        (raw, via wgpu-native / SDL_gpu)
frame_native (window, via SDL2 / GLFW)
frame_webview (via system webview)
ui_widgets  (on frame + gpu)
```

Rust's proven layering, for comparison:

```
                    ┌── ui: egui / iced ──┐
                    │                     │
   frame: winit/tao │        integration  │   gpu: wgpu
   (window, event   │  (raw-window-handle │   (Adapter/Device/
    loop, input)    │        handoff)     │    Queue/Surface)
                    └─────────────────────┘
   webview branch: tao ──▶ wry ──▶ HTML/JS  (+ tauri IPC bridge)
```

Verdict: **the proposal matches the Rust layering in substance**, with three
corrections.

1. **`frame_native` ≈ winit/tao — correct.** Window + event loop + input only,
   no rendering. SDL2/GLFW are the right C equivalents (raylib if you also want
   drawing/audio in the same lib).

2. **`gpu_` ≈ wgpu/wgpu-native — correct, but the seam is the integration
   layer, not either crate.** In Rust, *neither* wgpu nor winit owns the surface:
   the app/integration calls `Instance::create_surface(window)` via
   `raw-window-handle`. MojoAkku should copy that shape explicitly — `frame_native`
   exposes a native window handle type; `gpu_` can only build a Surface from it.
   `raw-window-handle` has no Mojo equivalent yet, so this is the first thing to
   design.

3. **`frame_webview` is a sibling of `ui_widgets`, not a layer under it.**
   In Rust, wry does **not** sit on wgpu or on egui/iced; it sits directly on the
   window and replaces the whole GPU+widget stack with the OS webview + HTML/JS.
   Tauri = tao (frame) + wry (webview) + IPC. So the MojoAkku tree should be:

   ```
   frame_native ──┬── gpu_ ──▶ ui_widgets        (native GPU path, à la winit+wgpu+egui)
                  └── frame_webview ──▶ (HTML/JS) (system-webview path, à la tao+wry)
   ```

   `frame_webview` must depend on `frame_native` for the window/event loop, and
   on nothing in `gpu_`/`ui_widgets`.

**Matches / does not match, one line each:**

- Matches: separate window layer (winit/SDL2/GLFW), separate GPU layer
  (wgpu/wgpu-native), UI on top of both (egui/iced).
- Matches: webview as its own layer over the window (wry over tao).
- Does **not** match: naming `frame_webview` as if it were a UI toolkit peer of
  `ui_widgets`; it is a mutually exclusive rendering branch.
- Does **not** exist in Rust: a `frame_*` layer that *bundles* SDL2's own
  renderer/GPU. Keep `frame_` and `gpu_` separable, as winit and wgpu are.

---

## Biggest risks (ranked)

1. **Window→GPU surface handoff.** `wgpu-native` needs a platform-specific
   surface descriptor (Xlib/`HWND`/`CAMetalLayer`); Mojo has no
   `raw-window-handle` equivalent, and `wgpu-mojo` today implements surface
   creation **for Xlib and Wayland only** — "macOS is compute-only today… there
   is no `CAMetalLayer` path yet" (<https://github.com/Hundo1018/wgpu-mojo>).
   This is the concrete blocker for a working `gpu_` + `frame_native` pair on
   Metal.

2. **wgpu-native ABI pin.** wgpu-mojo pins **exactly one** wgpu-native revision
   ("currently v29.0.0.0") because "wgpu-native renumbered its entire
   `0x0003xxxx` SType enum in the v29.0.0.0 → v29.0.1.1 patch release. A
   mismatched library still loads and still runs. It just misreads every extras
   chain, silently." (README). A Mojo `gpu_` must treat a wgpu-native bump as
   breaking, not patch.

3. **Mobile entry-point plumbing has no Mojo equivalent.** Android needs a
   Java/Kotlin `Activity` + `cdylib` + JNI glue (Rust's `android-activity`
   crate); iOS needs an Xcode project + AppDelegate. "It's not possible to
   subclass an Activity from Rust / JNI code alone"
   (<https://github.com/rust-mobile/android-activity>). Mojo would have to write
   that Java/Kotlin/Swift glue by hand. This is the largest long-term cost and
   argues for deferring mobile out of `frame_native` v1.

4. **Webview licenses/complexity.** WebKitGTK is LGPL-family `GUESS:` and pulls
   in GTK; WebView2/WKWebView are proprietary OS components. Shipping a
   `frame_webview` library means per-platform system-dependency handling (the
   exact burden Tauri documents at
   <https://v2.tauri.app/start/prerequisites/>).

---

## Sources (primary)

- winit README — <https://github.com/rust-windowing/winit>
- winit FEATURES.md (scope, platforms) —
  <https://github.com/rust-windowing/winit/blob/master/FEATURES.md>
- winit `EventLoop` docs (types, traits, mobile ext) —
  <https://docs.rs/winit/latest/winit/event_loop/struct.EventLoop.html>
- tao README — <https://github.com/tauri-apps/tao>
- wgpu README — <https://github.com/gfx-rs/wgpu>
- wgpu `Surface` docs — <https://docs.rs/wgpu/latest/wgpu/struct.Surface.html>
- wgpu-native README (C ABI, Mojo binding) —
  <https://github.com/gfx-rs/wgpu-native>; license `wgpu-native/LICENSE.MIT`
- Tauri ARCHITECTURE.md — <https://github.com/tauri-apps/tauri/blob/dev/ARCHITECTURE.md>
- Tauri prerequisites — <https://v2.tauri.app/start/prerequisites/>
- Tauri develop / mobile — <https://v2.tauri.app/develop/> and
  <https://v2.tauri.app/start/migrate/from-tauri-1/>
- WRY README (per-OS web engines, Android glue) —
  <https://github.com/tauri-apps/wry/blob/dev/README.md>
- Wails README + LICENSE — <https://github.com/wailsapp/wails>
- `android-activity` README (Android glue, NativeActivity vs GameActivity) —
  <https://github.com/rust-mobile/android-activity>
- egui README (immediate mode, integrations) — <https://github.com/emilk/egui>
- iced README (Elm architecture, wgpu/tiny-skia, winit shell) —
  <https://github.com/iced-rs/iced>
- SDL license — <https://www.libsdl.org/license.php>
- GLFW license — <https://www.glfw.org/license.html>; README —
  <https://github.com/glfw/glfw>
- raylib README + LICENSE — <https://github.com/raysan5/raylib>
- WebKitGTK — <https://webkitgtk.org/>
- wgpu-mojo (existing Mojo binding; GLFW canvas; macOS limitation; ABI pin) —
  <https://github.com/Hundo1018/wgpu-mojo>
- Mojo C-FFI — <https://mojolang.org/docs/manual/c-ffi/> and
  `mojov1/interop/calling-c` (local buch)
