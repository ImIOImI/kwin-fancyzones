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

Early scaffolding. The repo currently contains:

- A **headless KWin 6 test environment** (Docker) so changes can be validated
  automatically on this machine.
- A **skeleton KWin script** (`src/`) that proves the pipeline end-to-end: it
  loads into KWin, enumerates windows, and repositions one.

Still to come: the zone data model, the visual zone editor, the drag-time snap
overlay, multi-monitor support, and keyboard shortcuts.

## Repo layout

```
docker/
  Dockerfile          # ubuntu:25.04 + KWin 6 + Xvfb + xdotool + screenshot tools
  entrypoint.sh       # dispatches: smoke | session | shell
scripts/
  build-image.sh      # docker build
  test.sh             # build (if needed) + run a harness command in the container
  harness/
    lib.sh            # fz_* helpers: start session, load script, drag, screenshot
    start-session.sh  # bring up Xvfb + kwin_x11 + load the mounted script
    run-smoke-test.sh # end-to-end behavioral test
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

Run the smoke test (builds automatically if the image is missing):

```bash
./scripts/test.sh
```

A pass looks like:

```
SMOKE TEST PASSED — script loaded and repositioned the window (...)
```

Logs and a screenshot land in `./out/` (`kwin.log`, `xvfb.log`, `smoke.png`).

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
