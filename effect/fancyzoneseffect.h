#pragma once
// kwin-fancyzones — C++ KWin effect.
//
// v0.5: render the zone overlay via QuickSceneEffect (QML), shown while a window is
// being moved with Shift held. Verified headless: activating the effect mid-move does
// NOT cancel the drag (move-finish still fires), so QuickSceneEffect is viable as the
// drag overlay (much simpler than OffscreenQuickScene + manual paintScreen).
// TODO: confirm the input/grab interaction on real Kubuntu hardware.
#include <effect/quickeffect.h>

namespace KWin
{
class EffectWindow;

class FancyZonesEffect : public QuickSceneEffect
{
    Q_OBJECT
public:
    FancyZonesEffect();
    ~FancyZonesEffect() override;

    static bool supported();
    int requestedEffectChainPosition() const override { return 60; }

private:
    void hookWindow(EffectWindow *w);
    void updateGate();
    void setActive(bool active);

    Qt::KeyboardModifiers m_mods = Qt::NoModifier;
    EffectWindow *m_movingWindow = nullptr;
    bool m_active = false;
};

} // namespace KWin
