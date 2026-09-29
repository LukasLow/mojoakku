# Research: Window / Graphics / GPU access in Odin and Zig

Scope: how two low-level languages without a built-in GUI expose `frame_*` (windowing),
`gpu_*` (raw GPU) and `ui_*` (widget layers). Every claim has a source. Guesses marked `GUESS:`.

Date: 2026-09-29. All URLs verified this session unless noted.

---

## 1. Odin `vendor:` packages

**What `vendor:` is.** The `vendor:` prefix is an Odin package collection that ships with the
compiler, curated by the Odin team. The README explicitly asks that nobody open PRs for new
`vendor:` packages without consulting the team first ("often results in a duplication of effort").
Source: https://github.com/odin-lang/Odin/tree/master/vendor (README.md).

**Graphics/windowing bindings that ship (verified directory listing, master):**
- Window/input: `glfw`, `sdl2`, `sdl3`, `x11`, `windows` (Win32), `egl`
- Rendering/GPU: `OpenGL`, `vulkan`, `directx`, `wgpu` (incl. `glfwglue`, `sdl2glue`, `sdl3glue`),
  `darwin/Metal`, `darwin/MetalKit`, `darwin/QuartzCore`, `darwin/CoreVideo`, `darwin/Foundation`
- Web: `wasm/WebGL` (for `js_wasm32` target)
- Game/utility: `raylib`, `nanovg`, `microui` (a port written *in Odin*), `fontstash`, `stb/*`,
  `miniaudio`, `box2d`, `cgltf`, `commonmark`, `curl`, `lua`, `zlib`, `ENet`, `portmidi`, `ggpo`, `OpenEXRCore`
Sources: https://github.com/odin-lang/Odin/tree/master/vendor (list),
https://github.com/odin-lang/Odin/tree/master/vendor/darwin (Metal/MetalKit/QuartzCore/CoreVideo/Foundation),
https://github.com/odin-lang/Odin/tree/master/vendor/wasm (WebGL only, `js_wasm32`),
https://github.com/odin-lang/Odin/tree/master/vendor/wgpu (native + JS + glue packages).

**Structure: one package (directory) per C library.** Each vendor entry is a directory of Odin
files with `package <name>`. Examples: `vendor/vulkan/` holds `core.odin`, `enums.odin`,
`procedures.odin`, `structs.odin` plus a `_gen/` folder — i.e. the API is split by kind, not by
C header. Source: https://github.com/odin-lang/Odin/tree/master/vendor/vulkan.

**`foreign import` — the mechanism that makes it possible.**
```odin
foreign import kernel32 "system:kernel32.lib"

foreign kernel32 {
    ExitProcess :: proc "stdcall" (exit_code: u32) ---
}
```
- `foreign import` names a library (a `.lib`/`.dylib`/`.so`, `system:` prefix, or even an `.asm`
  file the Odin compiler assembles and links). The name is then used to open a `foreign` block.
- Inside a `foreign` block, procedures declare no body and end in `---`; default calling
  convention is cdecl/`"c"` unless overridden (`@(default_calling_convention="std")`).
- Global variables can be imported the same way (`x: i32` inside the block).
- Block attributes: `default_calling_convention`, `extra_linker_flags`, `link_prefix`,
  `link_suffix`, `private`, `require_results`.
Source: https://odin-lang.org/docs/overview/ → section "Foreign system" (lines ~3845–3911 of the
fetched overview) and "Using a `vendor` library".

**Vulkan specifically is generated, not hand-written:** vendor README says the Vulkan bindings
"are automatically generated from headers provided by Khronos" and ship under Apache-2.0.
Source: https://github.com/odin-lang/Odin/tree/master/vendor (README, "Vulkan" section).

---

## 2. Odin examples — how thin is the binding?

**Documented examples exist and are official.**
- The language overview itself walks through a complete `vendor:glfw` window program and states:
  "there is little difference to how someone would use `vendor:glfw` in this case. It's not always
  perfect but often good enough to port existing code quickly."
  Source: https://odin-lang.org/docs/overview/ ("Using a `vendor` library").
- The `odin-lang/examples` repo ships directories: `glfw/window`, `sdl2`, `sdl3`, `raylib`,
  `opengl`, `vulkan/triangle_glfw`, `wgpu`, `metal`, `directx`, `wasm`.
  Source: https://github.com/odin-lang/examples (repo listing + README).
- The overview documents calling back into Odin contexts from C callbacks (the GLFW error
  callback example), which is the one place the port is not a pure 1:1 translation.
  Source: https://odin-lang.org/docs/overview/ (explicit context definition / vendor:glfw callback).

**Thinness verdict:** mostly 1:1 to the C API (same names, "case notation should remain the same as
the original authors intended, to make porting code easier" — overview). But some packages add
idiomatic helpers:
- `vendor:OpenGL`: "Bindings for the OpenGL graphics API **and helpers in idiomatic Odin** to, for
  example, reload shaders".
- `vendor:raylib`: "Bindings ... **in idiomatic Odin**".
- `vendor:microui`: a **port written in Odin** (not a C binding).
Source: https://github.com/odin-lang/Odin/tree/master/vendor (README per package).

---

## 3. Zig — windows/graphics with no stdlib GUI

Zig's standard library has **no GUI/windowing**. Source: the Zig language reference's stdlib
section lists algorithms/containers/IO only — no window API; the manual's C chapter exists solely
to interop with C:
https://ziglang.org/documentation/master/ (sections "C", "Zig Standard Library").

Real approaches and projects:

1. **Translate the C headers into Zig** (classic: `@cImport`; now build-system `addTranslateC`).
   This is the dominant route for SDL/GLFW/Vulkan headers.
   Source: https://ziglang.org/download/0.16.0/release-notes.html ("@cImport Moving to Build System").
2. **Community binding packages**, e.g. `zig-gamedev/zglfw` — "Zig build package and bindings for
   GLFW". Source: https://github.com/zig-gamedev/zglfw.
3. **Auto-generated raylib bindings**: `raylib-zig/raylib-zig` — "Manually tweaked, auto-generated
   raylib bindings". Source: https://github.com/raylib-zig/raylib-zig. Also `ryupold/raylib.zig`
   ("Idiomatic Zig bindings for raylib"), source: https://github.com/ryupold/raylib.zig.
4. **Zig-native stack — Mach** (`machengine.org`): "Mach offers a pure Zig alternative to those
   libraries [GLFW/SDL/Raylib]. ... use just the part of Mach that opens a window, uses a low-level
   graphics API, and use Zig as your shading language." `mach-glfw` is a Zig GLFW package, and
   `mach.core` is the windowing module. Sources: https://machengine.org/docs/modularity/,
   https://machengine.org/pkg/mach-glfw/.
   `GUESS:` mach.core/mach-glfw is a Zig re-implementation/translation of GLFW rather than a thin C
   binding (the docs call it "pure Zig"), but I did not read its source to confirm.
5. **zig-gamedev** is the umbrella collection of Zig bindings/libraries recommended on the Zig
   forum. Source: https://ziggit.dev/t/zig-and-opengl/3972.

The community also broadly recommends **hand-tweaked bindings over raw `@cImport`** because C
pointer semantics are ambiguous (single vs. many, nullable): "I know I can use @cImport, but I've
also seen people recommend using hand-tweaked bindings instead."
Source: https://ziggit.dev/t/using-c-libraries-in-zig/16805; same point in
https://github.com/ryupold/raylib.zig ("not decidable for the generator what a pointer to C means").

---

## 4. Zig `translate-c` vs. Odin's foreign import

**Zig offers an actual C-header translator.**
- CLI: `zig translate-c <file.h>` writes translated Zig to stdout; flags `-I`, `-D`,
  `-cflags … --`, `-target` forwarded to clang. **The `-target` and `-cflags` used for translation
  must match compilation, or you get subtle ABI breaks.**
  Source: https://ziglang.org/documentation/master/ (section "C Translation CLI").
- **Non-translatable C is "demoted", not fatal:** `goto`, bitfield structs and token-pasting
  macros cannot be translated. Untranslatable structs/unions become `opaque{}`, untranslatable
  functions become `extern` declarations, and top-level macro/global failures emit
  `@compileError` (lazy analysis means it only fires if you use it).
  Source: https://ziglang.org/documentation/master/ (section "Translation failures").
- **`@cImport` is deprecated in 0.16.** Translation moves to the build system
  (`b.addTranslateC(...)` → `translate_c.createModule()`, then `@import("c")`), or to the official
  external package `ziglang/translate-c`. Translation now uses arocc instead of libclang.
  Sources: https://ziglang.org/download/0.16.0/release-notes.html
  ("@cImport Moving to Build System"), https://codeberg.org/ziglang/translate-c (README: "intended
  to replace @cImport and zig translate-c").

**Odin has no equivalent compiler-driven header translator.** The compiler consumes already-written
`foreign` declarations; it does not parse C headers. `odin build` links/binds, it does not translate.

Binding generation in Odin is therefore third-party:
- `karl-zylinski/odin-c-bindgen` — generates Odin bindings from C headers using **libclang ≥16**,
  configurable (`bindgen.sjson`: prefix stripping, enum→bit_set, type/field overrides, …), with
  `_footer.odin` files for hand-written extras. Source: https://github.com/karl-zylinski/odin-c-bindgen.
- `Breush/odin-binding-generator` — an Odin library converting a C header to an Odin binding file.
  Source: https://github.com/Breush/odin-binding-generator.

**Comparison table**

| | Odin | Zig |
|---|---|---|
| Compiler translates C headers | No | Yes (`translate-c`, `addTranslateC`; arocc since 0.16) |
| Binding generation | Third-party tools (libclang), vendor bindings curated by hand | Compiler/build-system + official `translate-c` package |
| Consuming the binding | `foreign import` + `foreign {}` block, `---` procs | `pub extern fn …` (normal Zig decl) |
| Link names / calling conv | explicit `foreign import`, `@(link_name=…)`, calling conv attrs | ordinary `extern`/`@extern`, ABI in the type system |

---

## 5. Reaching Vulkan / Metal / wgpu

**Odin (all native, via vendor):**
- `vendor:vulkan` — auto-generated from Khronos Vulkan-Headers (Apache-2.0).
- `vendor:wgpu` — native + JS (`wgpu_native.odin`, `wgpu_js.odin`, `wgpu.js`), plus platform glue
  packages `glfwglue`, `sdl2glue`, `sdl3glue`; ships a prebuilt Windows x86_64 MSVC lib.
- `vendor:darwin/Metal` (+ MetalKit, QuartzCore, CoreVideo): Apple-native path.
- `vendor:directx`: D3D on Windows. `vendor:OpenGL` + `vendor:egl`: GL/GLES.
Sources: https://github.com/odin-lang/Odin/tree/master/vendor/vulkan,
https://github.com/odin-lang/Odin/tree/master/vendor/wgpu,
https://github.com/odin-lang/Odin/tree/master/vendor/darwin,
https://github.com/odin-lang/Odin/tree/master/vendor (README for OpenGL/DirectX entries).

**Zig:**
- Vulkan/Metal/GL by `@cImport`/`addTranslateC` of the vendor headers, or by a bindings package.
- `zig-gamedev` provides curated GPU/graphics bindings and examples; `zglfw` is its GLFW binding.
  Source: https://github.com/zig-gamedev/zglfw, https://ziggit.dev/t/zig-and-opengl/3972.
- Mach targets GPU through its own `mach.gpu` module plus shader tooling rather than a C binding;
  `GUESS:` it wraps wgpu-native/Dawn-class backends — I did not verify the backend list this session.
  Source for the module's existence: https://machengine.org/docs/gpu/.

---

## 6. What this means for a Mojo port

**Mojo's actual FFI surface (verified, Mojo 1.1.0):**
- `std.ffi.external_call[callee, return_type](args…)` — call a C symbol by name with compile-time
  resolution; `num_fixed_args` for variadics. Resolves symbols in the process image.
- `std.ffi.OwnedDLHandle` — RAII `dlopen` handle; `get_function[ReturnType]("name")`,
  `check_symbol()`. This is the route to libraries (the docs literally name "graphics, databases,
  GPU vendor libraries").
- `std.ffi` C aliases (`c_int`, `c_long`, `c_size_t`, …) track the target C ABI.
- No header parsing anywhere: **"That makes you the type checker. The C header is the contract, and
  matching it is your job."** Signature mistakes "usually produce a plausible result rather than a
  crash". `get_function()` takes the return type only, so argument types are not connected to C.
- There is already a binding helper in the ecosystem: `mojo-bindgen` (PyPI) aims to "make binding
  generation easy and faithful … and fail conservatively when a declaration cannot be modeled
  correctly."
Sources: https://mojolang.org/docs/manual/c-ffi/ (all quotes above),
https://mojolang.org/docs/std/ffi/ , https://pypi.org/project/mojo-bindgen/.

**Equivalent Mojo workflow for `frame_*` / `gpu_*`:**
1. Ship/locate the C library as a shared lib (`.dylib`/`.so`/`.dll`).
2. Hand-write a thin Mojo module per library: mirror C structs as `RegisterPassable`,
   declare each function with `external_call` (static, link-time) or `OwnedDLHandle.get_function`
   (runtime `dlopen`, best for optional/versioned libraries and for `mojo run`).
3. Re-export a curated, low-vision-friendly API (`frame_create_window`, `frame_poll_events`, …) on
   top of the raw 1:1 layer — the same "thin binding + idiomatic helpers" split Odin uses for
   OpenGL/raylib.

**What Odin/Zig can do that Mojo cannot yet:**
- Translate C headers automatically at build time (Zig `translate-c`/`addTranslateC`; Odin via
  third-party libclang bindgen, though not in-compiler). Mojo has no header parser at all.
- Have the compiler verify/derive call signatures against the C declaration. In Mojo a wrong
  signature silently misbehaves (documented).
- Statically link a C library through the language's own build system in one step
  (`foreign import` / `linkSystemLibrary`). Mojo links through a C compiler driver and names
  system libs via `MODULAR_MOJO_MAX_SYSTEM_LIBS` (documented workaround for `DSO missing`).
- Call functions returning large structs by value (Mojo requires `RegisterPassable`; big-struct
  returns must be done via a hidden out-pointer).
- Compile or expose C code the language owns (callbacks: Mojo needs `abi("C")` thin functions,
  which Odin/Zig also need, so that one is *the same*).

**What is the same:**
- A direct native call with no translation layer / no extra runtime overhead (Mojo claim:
  "A C call from Mojo runs as fast as handwritten C").
- The need for hand-written bindings, callback functions marked C-ABI, manual memory ownership
  across the boundary, and manual platform-specific library names (`platform_map` in Mojo is the
  analogue of Odin's `when ODIN_OS == …` and Zig's comptime target checks).
- A separate, curated high-level layer for ergonomics.

**Important divergence for `gpu_*`: Mojo is *ahead* here, not behind.** Mojo already has a
first-party GPU programming path: the MAX accelerator library `max.gpu` with `DeviceContext`
(api = `"cuda"` / `"hip"` / `"metal"`), `DeviceBuffer`/`HostBuffer`, `compile_function` and
`enqueue_function`, `block_idx`/`thread_idx`/`global_idx`. So a raw `gpu_*` namespace in MojoAkku
should probably *wrap* MAX, not bind Vulkan by hand. Sources:
https://max.modular.com/gpu/fundamentals/ , https://mojolanguage.org/docs/std/sys/info/ (the page
fetched was https://mojolang.org/docs/std/ffi/; GPU detection functions are in `std.sys.info`).
Odin and Zig, by contrast, have **no first-party GPU API** — they bind Vulkan/Metal/wgpu from C.

---

## 7. Ranked first C target for hand-written Mojo bindings

Candidates: SDL2, GLFW, raylib, sokol. (A fifth, SDL3, is the same codebase as SDL2 with a
modernised API and a `.lib`/`.dll` shipped in Odin's vendor listing; include it as a later step.)

| Criterion | SDL2 | GLFW | raylib | sokol |
|---|---|---|---|---|
| (a) Simplicity of C API | Medium: large but flat subsystem API (window/input/timer) | Small and focused: window + input + context only, no rendering | High-level and flat, but large (~500+ fns) and struct/palette-heavy | Very small per-header, but STB-style: needs `SOKOL_IMPL` + backend `#define` in exactly one C TU |
| (b) Cross-platform incl. mobile | Yes: desktop + Android + iOS (repo ships `android-project/`, Xcode dirs) | **No mobile**: Windows, macOS, Wayland/X11 only — long-standing issue #1726 | Yes: Windows/Linux/macOS/FreeBSD/RPi/Android/HTML5 | Yes in sokol_app: Win32, macOS, Linux(X11), iOS, WASM, Android, UWP |
| (c) License | zlib | zlib/libpng | zlib | zlib |
| (d) Suitability for hand-written Mojo bindings | Good: stable C ABI, ships as shared lib → `OwnedDLHandle`/`external_call` | Good C ABI, small surface, but no mobile and callbacks are essential (needs `abi("C")`) | Best ergonomics; ships as shared/static lib; big surface to hand-write | **Poor for hand-written Mojo bindings**: no prebuilt library, you must compile the C implementation yourself; each backend needs defines; macOS needs an Objective-C TU |

Sources: SDL — https://github.com/libsdl-org/SDL (README + `android-project/`, `Xcode/` dirs;
LICENSE.txt, zlib). GLFW — https://www.glfw.org/faq (supported platforms: "Windows (XP and later),
macOS … and Unix-like … with Wayland or X11"), https://github.com/glfw/glfw/issues/1726 (no
iOS/Android), license from Odin vendor README (zlib/libpng). raylib — https://www.raylib.com/
("supported platforms" images list Windows/Linux/macOS/FreeBSD/RPi/Android/HTML5; "NO external
dependencies"; bindings page lists "raylib-odin"), license zlib per Odin vendor README and
https://www.raylib.com/license.html. sokol — https://github.com/floooh/sokol (README: `sokol_app.h`
platforms + 3D-APIs; "Zlib license"; "Define `SOKOL_IMPL` … in exactly one C or C++ translation
unit"; "macOS and iOS … must compile the implementation file as Objective-C or Objective-C++").

**Recommendation: SDL2 first.**
- It is the only candidate that is simultaneously: zlib-licensed, mobile-capable, low-level enough
  to map 1:1 onto a `frame_*` windowing namespace, and **shipped as an installable shared library**
  — which is exactly what Mojo's `OwnedDLHandle`/`external_call` consume without any header
  translation.
- It is also the target Odin itself treats as a first-class vendor binding (`sdl2` and `sdl3`,
  plus `vendor:wgpu/sdl2glue` and `sdl3glue`), so a later wgpu/Vulkan layer has an existing glue
  pattern to copy. Source: https://github.com/odin-lang/Odin/tree/master/vendor (SDL2/SDL3 entries),
  https://github.com/odin-lang/Odin/tree/master/vendor/wgpu.
- GLFW is the better *second* target if a pure-OpenGL, desktop-only path is wanted (smallest
  surface to hand-write, and Odin's overview uses it as the canonical FFI teaching example).
- raylib is the best *convenience* target for `ui_*`/simple 2D: one library gives window + render +
  input + audio, is mobile/web-capable, and already has Odin and Zig binding precedents to mirror.
- **Do not start with sokol**: Mojo cannot compile the C implementation that sokol requires, and
  there is no prebuilt sokol library to `dlopen`.

`GUESS:` If MojoAkku's `gpu_*` is meant to be raw Vulkan rather than MAX, `vendor:vulkan`'s split
(core/enums/procedures/structs, generated from Khronos headers) is the structural template a
hand-written Mojo binding should copy — but note Vulkan's ~1000+ entry points make it a poor first
C target versus SDL2.

---

## Open questions / not verified
- Whether `mach.gpu` wraps wgpu-native, Dawn or a custom backend (not checked this session).
- Exact function counts for raylib/GLFW (stated qualitatively from docs, not counted).
- mojo-bindgen's maturity/coverage — only its stated goal was read; it is a third-party PyPI tool.
- Whether Mojo's `external_call` can bind a *static* C library at all (docs describe symbol
  resolution and `dlopen`; static linking is only hinted at via the C-compiler-driver path).
