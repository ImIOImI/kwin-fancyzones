#pragma once
// kwin-fancyzones — C++ KWin effect.
// At this stage it only proves the integration: the effect loads in a headless
// kwin_wayland session and can observe pointer + keyboard-modifier state during an
// interactive window move (which a script cannot). The FancyZones overlay + snapping
// logic builds on top of this.
#include <effect/effect.h>

namespace KWin
{

class FancyZonesEffect : public Effect
{
    Q_OBJECT
public:
    FancyZonesEffect();
    ~FancyZonesEffect() override;

    static bool supported();
    int requestedEffectChainPosition() const override { return 10; }

private:
    bool m_moving = false;
};

} // namespace KWin
