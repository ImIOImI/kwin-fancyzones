# syntax=docker/dockerfile:1
# Headless KDE Plasma 6 / KWin test environment for the kwin-fancyzones project.
#
# Ubuntu 25.04 (Plucky) ships KWin 6.3.x — the same Plasma 6 generation as current
# Kubuntu. We run kwin_x11 on Xvfb so the mouse can be driven with xdotool (XTEST),
# which needs no privileged container or /dev/uinput access.
ARG UBUNTU_VERSION=25.04
FROM ubuntu:${UBUNTU_VERSION}

LABEL org.opencontainers.image.title="kwin-fancyzones-test" \
      org.opencontainers.image.description="Headless KWin 6 test environment for kwin-fancyzones" \
      org.opencontainers.image.source="https://github.com/ImIOImI/kwin-fancyzones"

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:99 \
    XDG_RUNTIME_DIR=/tmp/xdg-runtime \
    HOME=/root \
    FZ_SRC=/opt/fz/src

# KWin 6 + a headless X stack + input/screenshot tooling.
#   kwin-x11/kwin-common : the window manager + scripting engine
#   xvfb                 : virtual X server (no GPU needed)
#   xdotool              : drives the mouse/keyboard via XTEST (drag simulation)
#   wmctrl, x11-utils    : window listing / xdpyinfo readiness checks
#   xterm + xfonts-base  : a real "normal" window to snap during tests
#   imagemagick          : screenshots (import / magick import)
#   dbus-x11             : dbus-launch for a session bus
#   libglib2.0-bin       : gdbus, used to talk to org.kde.KWin
#   libgl1-mesa-dri      : llvmpipe software GL (some KWin paths probe for GL)
RUN apt-get update && apt-get install -y --no-install-recommends \
      kwin-x11 \
      kwin-common \
      xvfb \
      x11-utils \
      x11-xserver-utils \
      x11-apps \
      xdotool \
      wmctrl \
      xterm \
      xfonts-base \
      imagemagick \
      dbus-x11 \
      libglib2.0-bin \
      libgl1-mesa-dri \
      procps \
      psmisc \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Xvfb has no real GPU; we only need window management, not compositing/effects.
RUN mkdir -p /root/.config \
    && printf '[Compositing]\nEnabled=false\n' > /root/.config/kwinrc

# Harness scripts are baked in (they change rarely and live behind the cached apt layer).
# The KWin script package itself is bind-mounted at /opt/fz/src at run time for fast iteration.
COPY scripts/harness/ /opt/fz/harness/
COPY docker/entrypoint.sh /opt/fz/entrypoint.sh
RUN chmod +x /opt/fz/harness/*.sh /opt/fz/entrypoint.sh

WORKDIR /opt/fz
ENTRYPOINT ["/opt/fz/entrypoint.sh"]
CMD ["smoke"]
