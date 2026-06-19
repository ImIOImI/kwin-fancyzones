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

**v0.1 — core snapping works**, validated headlessly. The repo contains:

- A **headless KWin 6 test environment** (Docker) so changes are validated
  automatically on this machine.
- A **KWin script** (`src/`) that snaps a window to a zone when you finish moving
  it, with **overlapping zones** resolved by a smallest-zone-wins rule.

### How snapping works

Zones are defined as percentages of the screen work area and **may overlap**. The
default layout is a 3-column grid plus a centered `focus` zone that overlaps the
middle column:

```
ZONES = [ left | middle | right ]  +  focus (centered, overlapping middle)
```

On `interactiveMoveResizeFinished`, the script reads `workspace.cursorPos`, finds
every zone containing the cursor, and snaps the window to the **smallest** one — so
a small zone stacked on a big one stays reachable. (This overlap behavior is the
gap vs. KDE's built-in recursive-split tiling.)

Still to come: a modifier gate so not *every* drag snaps, the **drag-time visual
overlay**, a visual zone editor, layout persistence, multi-monitor handling, and
keyboard shortcuts.

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
  metadata.json
  contents/code/main.js
out/                  # harness logs + screenshots (git-ignored)
```

## Testing model

This project is developed on WSL2, but **KWin can't run there** — it needs a real
display server and window manager. So **all tests run inside a Docker container**
that boots a headless KWin 6 session:

```
Xvfb (virtual X11 display)
  └─ kwin_x11            ← the window manager under test
       └─ KWin script    ← src/contents/code/main.js, loaded via D-Bus (gdbus)
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
SMOKE TEST PASSED — KWin is up and the script loaded cleanly
SNAP TEST PASSED — window snapped to the overlapping 'focus' zone (...)
```

The snap test drags a window so the cursor finishes at screen center — a point
inside both the `middle` column and the smaller `focus` zone — and asserts the
window snapped to `focus`, proving overlap resolution.

Logs and screenshots land in `./out/` (`kwin.log`, `xvfb.log`, `smoke.png`, `snap.png`).

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
