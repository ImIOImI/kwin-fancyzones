#pragma once
// kwin-fancyzones — C++ KWin effect.
//
// v0.5 logic: while a window is moved with Shift held, select the zone under the
// cursor live (nearest-center among overlapping zones) and snap the window to it on
// drop. Uses a plain Effect so mouseChanged keeps firing during the move (KWin's
// move grab + a QuickSceneEffect mouse-interception conflict — interception buffers
// motion until the overlay closes, which breaks live tracking). The passive visual
// overlay (OffscreenQuickScene + paintScreen) is the next step; this step is the
// fully headless-testable selection + snap behavior.
//
// Snapping uses EffectWindow::window()->moveResize() — an internal KWin API (the only
// way an effect can resize a window). TODO: couples to KWin's internal ABI.
#include <effect/effect.h>

#include <QList>
#include <QPointF>
#include <QRectF>
#include <QString>

namespace KWin
{
class EffectWindow;

class FancyZonesEffect : public Effect
{
    Q_OBJECT
public:
    FancyZonesEffect();
    ~FancyZonesEffect() override;

    int requestedEffectChainPosition() const override { return 60; }

private:
    struct Zone { QString name; double x, y, w, h; }; // percentages of the screen

    void hookWindow(EffectWindow *w);
    void updateGate();
    void setActive(bool active);
    void updateHighlight();
    QRectF rectFor(const Zone &z) const;
    int pick(const QPointF &cursor) const; // nearest-center among zones containing cursor; -1 if none

    QList<Zone> m_zones;
    Qt::KeyboardModifiers m_mods = Qt::NoModifier;
    EffectWindow *m_movingWindow = nullptr;
    bool m_active = false;
    int m_highlight = -1;
    QPointF m_cursor;
};

} // namespace KWin
