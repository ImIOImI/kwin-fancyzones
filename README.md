# kwin-fancyzones

A [FancyZones](https://learn.microsoft.com/en-us/windows/powertoys/fancyzones)-style
window-snapping tool for **KDE Plasma (KWin)**.

The headline feature — and the reason this isn't just KDE's built-in tiling — is
**overlapping canvas zones**. Plasma's built-in custom tiling (`Meta+T`) is a
recursive split: every zone is a non-overlapping rectangle that tiles the screen
edge-to-edge. FancyZones' *canvas* layouts let zones be placed anywhere and
**overlap**, so you can drag a window onto one of several stacked zones. That's
the gap this project fills.

## Why KDE / KWin

KWin has a first-class **JavaScript scripting API** that runs *inside the
compositor*, so a script can freely move and resize any window on **both X11 and
Wayland** — without the sandbox restrictions that make this nearly impossible as
a GNOME-on-Wayland app. See the [KWin scripting docs](https://develop.kde.org/docs/plasma/kwin/).

## Status

**v0.2 — drag-time overlay + snapping**, validated headlessly (overlay rendering
confirmed by screenshot). The repo contains:

- A **headless KWin 6 test environment** (Docker) so changes are validated
  automatically on this machine.
- A **QML KWin script** (`src/`, a `declarativescript` package) that shows a
  translucent overlay of all zones while you drag a window, highlights the active
  zone with a filled glow, and snaps the window to it on drop — with **overlapping
  zones** that KDE's built-in recursive-split tiling can't express.

### How snapping works

Zones are defined as percentages of the screen work area and **may overlap**. The
default layout is a 3-column grid plus a lower-center `focus` zone that overlaps the
middle column:

```
ZONES = [ left | middle | right ]  +  focus (lower-center, overlapping middle)
```

While a window is being moved, a click-through `PlasmaCore.Dialog` overlay draws
every zone; a polling timer reads `Workspace.cursorPos` and highlights the zone
under the cursor. **Overlap rule:** among the zones containing the cursor, the one
whose **center is nearest the cursor** wins. On drop the window's `frameGeometry`
is set to that zone.

Still to come: a modifier gate so not *every* drag snaps, a visual zone editor,
layout persistence, multi-monitor handling, and keyboard shortcuts.

## Two implementations

The project deliberately has two parallel tracks:

- **`src/` — QML `declarativescript`** (above). Simple, unprivileged, and fully
  testable on the X11/Xvfb harness. Its limit: a KWin *script* cannot observe
  keyboard/mouse state *during* a drag, so it can't reproduce FancyZones' exact
  *hold-a-modifier-while-dragging* behavior.

- **`effect/` — C++ KWin effect** (the path to the **exact** FancyZones drag
  experience). An effect runs inside the compositor and *can* read live
  pointer + modifier state mid-drag (which the script can't). **v0.6 — the full
  drag experience:** while you drag a window with **Shift** held, a translucent
  **zone overlay** appears, the zone under the cursor **highlights live**
  (nearest-center among overlapping zones), and on drop the window **snaps** to it.
  Drag without Shift → nothing.

  - Overlay: a *passive* `OffscreenQuickScene` (QML) blitted in `paintScreen` — no
    input interception, so `mouseChanged` keeps tracking the cursor during the move.
    (`QuickSceneEffect` was tried first but its interception buffers cursor motion
    until the overlay closes, breaking live tracking.)
  - Snap: `EffectWindow::window()->moveResize()` (internal KWin API).
  - Verified headless: highlight follows the cursor (`middle`→`left`), window snaps
    to the right zone (`0,0 640x1080`), and the overlay renders (captured to a PNG —
    matches the design mockup). The on-screen *compositing* of the overlay is
    exercised headless and visually verified on real hardware.

### Testing the effect

The effect needs a real compositor, so it can't use the X11/Xvfb harness. Instead
`scripts/test-effect.sh` runs a **privileged** container that:

```
kwin_wayland --virtual --xwayland   ← software-composited headless session + a test window
  └─ effect/ built via CMake, loaded via the Effects D-Bus interface
scripts/harness-wayland/fakeinput.c ← injects pointer + keyboard via the
                                      org_kde_kwin_fake_input Wayland protocol
```

It runs two scenarios (each in a fresh session): drag a window **without** Shift
(must not activate) and drag while pressing **Shift** mid-drag (must activate, then
deactivate on finish).

```bash
./scripts/test-effect.sh
# => EFFECT TEST PASSED — move-hooked + Shift-gated activation ...
```

## Testing image

`docker/Dockerfile.effect` is a **comprehensive testing image** with everything both
harnesses need baked in — the window managers (`kwin_x11`, `kwin_wayland`), the X11
headless stack, software GL/EGL (llvmpipe), the C++ effect build toolchain
(`cmake`/`kwin-dev`/Qt6/KF6), and the Wayland protocol tooling. No per-run
`apt-install`.

CI (`.github/workflows/testing-image.yml`) builds it, runs **both** harnesses against
it, and — only if they pass — publishes it to GHCR:

```
ghcr.io/imioimi/kwin-fancyzones-test:latest
```

Use it locally instead of building:

```bash
FZ_IMAGE=ghcr.io/imioimi/kwin-fancyzones-test:latest ./scripts/test-effect.sh
```

Or build it locally: `./scripts/build-effect-image.sh` (→ `kwin-fancyzones-test:dev`,
the default for `test-effect.sh`).

## Try it visually (WSL2 / WSLg, or any Wayland session)

To actually *see and use* the effect — not just the headless test — run a **nested
KWin** in a window on your desktop with the effect loaded:

```bash
./scripts/run-visual.sh
```

A ~1600×900 KWin window opens (via WSLg on Windows 11 WSL2). Inside it are a couple
of test terminals — **hold Shift and drag one** to see the zone overlay, release to
snap. Close the window or press Ctrl-C to stop.

Requires a Wayland session (`WAYLAND_DISPLAY` set; WSLg provides this). The container
is privileged and mounts the WSLg wayland socket; it uses the GPU (`/dev/dxg`) if
present, otherwise software GL.

> **Note:** under WSLg, a nested KWin only gets *software (QPainter)* compositing,
> which WSLg may present as a black window even though the effect is running
> correctly (windows map, compositing active). To actually *see* it, use a real
> Plasma 6 session — see below.

## Install on a real Kubuntu (Plasma 6)

The reliable way to use it for real. **Requires Plasma 6 / KWin 6 — Kubuntu 24.10+ or
25.04** (not 24.04 LTS, which is still Plasma 5). On that machine:

```bash
git clone https://github.com/ImIOImI/kwin-fancyzones
cd kwin-fancyzones
./scripts/install.sh
```

It installs build deps, compiles the effect, installs `fancyzones.so` to the Qt6
plugin dir, and enables it in `kwinrc`. Log out/in (or `kwin_wayland --replace`) to
activate, then **drag a window with Shift held** to snap it to a zone.

## Configuring zones

Zones are read from a JSON config — no recompile needed. Copy the example and edit:

```bash
mkdir -p ~/.config/kwin-fancyzones
cp config/zones.example.json ~/.config/kwin-fancyzones/zones.json
# edit zones.json, then reload KWin (re-login, `kwin_wayland --replace`,
# or just toggle any KWin setting — the effect re-reads its config on reconfigure)
```

Each zone is percentages of the screen work area; zones may overlap (nearest-center
wins):

```json
{ "zones": [
  { "name": "left",  "x": 0,  "y": 0, "width": 50, "height": 100 },
  { "name": "right", "x": 50, "y": 0, "width": 50, "height": 100 }
] }
```

With no config file, a built-in default layout is used (3-column grid + a centered
`focus` zone). A visual zone editor is a future feature.

## Repo layout

```
docker/
  Dockerfile          # ubuntu:25.04 + KWin 6 + Xvfb + xdotool + screenshot tools
  entrypoint.sh       # dispatches: smoke | snap | test | session | shell
scripts/
  build-image.sh      # docker build
  test.sh             # build (if needed) + run a harness command in the container
  harness/
    lib.sh            # fz_* helpers: start session, load script, drag, screenshot
    start-session.sh  # bring up Xvfb + kwin_x11 + load the mounted script
    run-smoke-test.sh # quick check: session up + script loads cleanly
    run-snap-test.sh  # behavioral: drag a window into the overlapping zone
src/                  # the KWin script package (bind-mounted into the container)
  metadata.json       # declarativescript, MainScript = ui/main.qml
  contents/ui/main.qml
out/                  # harness logs + screenshots (git-ignored)
```

## Testing model

This project is developed on WSL2, but **KWin can't run there** — it needs a real
display server and window manager. So **all tests run inside a Docker container**
that boots a headless KWin 6 session:

```
Xvfb (virtual X11 display)
  └─ kwin_x11            ← the window manager under test
       └─ KWin script    ← src/contents/ui/main.qml, loaded via D-Bus
                           (gdbus → Scripting.loadDeclarativeScript)
xdotool                  ← drives the mouse to simulate window drags (XTEST)
imagemagick              ← screenshots for visual verification
```

X11 + Xvfb + `xdotool` is deliberate: input emulation works through XTEST with **no
privileged container and no `/dev/uinput`**. (Driving input on a headless
*Wayland* KWin would need `ydotool` + `/dev/uinput` + `--privileged`; we'll cross
that bridge only if Wayland-specific behavior needs testing. The KWin script
itself is display-server agnostic.)

## Usage

Build the image (first run pulls KWin + Qt6 + KF6, so it takes a few minutes):

```bash
./scripts/build-image.sh
```

Run the tests (builds automatically if the image is missing):

```bash
./scripts/test.sh          # smoke + snap (default)
./scripts/test.sh smoke    # just: session up + script loads cleanly
./scripts/test.sh snap     # just: drag a window into the overlapping zone
```

A pass looks like:

```
SMOKE TEST PASSED — KWin is up and the 'fancyzones' script is loaded
SNAP TEST PASSED — window snapped to the overlapping 'focus' zone (...)
```

The snap test drags a window toward the `focus` zone's center — a point inside both
the full-height `middle` column and the smaller `focus` zone — and asserts the window
snapped to `focus`, proving the nearest-center overlap rule. It also captures the
overlay mid-drag.

Logs and screenshots land in `./out/`: `kwin.log`, `xvfb.log`, `overlay.png` (zones
shown mid-drag), `snap.png` (result).

### Iterating on the KWin script

`src/` is bind-mounted into the container, so edit `src/contents/code/main.js`
and re-run `./scripts/test.sh` — no rebuild needed.

### Interactive session / shell

```bash
./scripts/test.sh session   # boot the session and hold (tails kwin.log)
./scripts/test.sh shell     # drop into a shell; then source the harness:
                            #   source /opt/fz/harness/lib.sh && fz_start_session
```

### Configuration

| Env var          | Default              | Meaning                          |
|------------------|----------------------|----------------------------------|
| `FZ_IMAGE`       | `kwin-fancyzones:dev`| Image tag                        |
| `UBUNTU_VERSION` | `25.04`              | Base image (25.04 → KWin 6.3)    |
| `FZ_SCREEN`      | `1920x1080x24`       | Virtual display geometry         |

## License

MIT — see [LICENSE](LICENSE).
