#pragma once
// kwin-fancyzones — C++ KWin effect.
//
// v0.4: move-hooked, Shift-gated activation. While a window is being interactively
// moved AND Shift is held, the effect "activates" (where the zone overlay will be
// shown). Releasing Shift mid-drag deactivates; finishing the move deactivates.
// The visual overlay (QuickSceneEffect QML) and snapping land next; for now
// activation is observable via logs and exercised by the headless harness.
#include <effect/effect.h>

namespace KWin
{
class EffectWindow;

class FancyZonesEffect : public Effect
{
    Q_OBJECT
public:
    FancyZonesEffect();
    ~FancyZonesEffect() override;

    static bool supported();
    int requestedEffectChainPosition() const override { return 10; }

private:
    void hookWindow(EffectWindow *w);
    void updateGate();
    void setActive(bool active);

    Qt::KeyboardModifiers m_mods = Qt::NoModifier;
    EffectWindow *m_movingWindow = nullptr;
    bool m_active = false;
};

} // namespace KWin
