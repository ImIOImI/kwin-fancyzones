// Minimal Wayland client that injects input via org_kde_kwin_fake_input.
// Reads commands from stdin, one per line:
//   m X Y      pointer_motion_absolute to (X,Y)
//   b BTN ST   button (BTN = evdev code e.g. 272=LEFT 273=RIGHT, ST 1=press 0=release)
//   k KEY ST   keyboard_key (KEY = evdev code e.g. 42=LEFTSHIFT, ST 1=press 0=release)
//   s MS       flush + roundtrip + sleep MS milliseconds
//   q          quit
#include <wayland-client.h>
#include "fake-input-client-protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static struct org_kde_kwin_fake_input *fake = NULL;

static void reg_global(void *d, struct wl_registry *r, uint32_t name,
                       const char *iface, uint32_t version) {
    if (strcmp(iface, "org_kde_kwin_fake_input") == 0) {
        uint32_t v = version < 5 ? version : 5;
        fake = wl_registry_bind(r, name, &org_kde_kwin_fake_input_interface, v);
        fprintf(stderr, "[fakeinput] bound org_kde_kwin_fake_input v%u\n", v);
    }
}
static void reg_remove(void *d, struct wl_registry *r, uint32_t name) {}
static const struct wl_registry_listener reg_listener = { reg_global, reg_remove };

int main(void) {
    struct wl_display *dpy = wl_display_connect(NULL);
    if (!dpy) { fprintf(stderr, "[fakeinput] cannot connect to wayland display\n"); return 1; }
    struct wl_registry *reg = wl_display_get_registry(dpy);
    wl_registry_add_listener(reg, &reg_listener, NULL);
    wl_display_roundtrip(dpy);
    if (!fake) { fprintf(stderr, "[fakeinput] org_kde_kwin_fake_input NOT advertised\n"); return 2; }

    org_kde_kwin_fake_input_authenticate(fake, "fancyzones-test", "headless input injection");
    wl_display_roundtrip(dpy);

    char line[256];
    while (fgets(line, sizeof line, stdin)) {
        char c = 0; int a = 0, b = 0;
        int n = sscanf(line, " %c %d %d", &c, &a, &b);
        if (n < 1) continue;
        switch (c) {
            case 'm': org_kde_kwin_fake_input_pointer_motion_absolute(fake, wl_fixed_from_int(a), wl_fixed_from_int(b)); break;
            case 'b': org_kde_kwin_fake_input_button(fake, a, b); break;
            case 'k': org_kde_kwin_fake_input_keyboard_key(fake, a, b); break;
            case 's': wl_display_flush(dpy); wl_display_roundtrip(dpy); usleep(a * 1000); continue;
            case 'q': goto done;
            default: continue;
        }
        wl_display_flush(dpy);
    }
done:
    wl_display_roundtrip(dpy);
    wl_display_disconnect(dpy);
    return 0;
}
