#pragma once
// kwin-fancyzones — C++ KWin effect.
//
// v0.6: the full drag experience. While a window is moved with Shift held, render a
// PASSIVE zone overlay (OffscreenQuickScene blitted in paintScreen — no input
// interception, so mouseChanged keeps tracking the cursor during the move), highlight
// the zone under the cursor live (nearest-center among overlapping zones), and on drop
// snap the window to it via EffectWindow::window()->moveResize() (internal KWin API).
#include <effect/effect.h>

#include <QList>
#include <QPointF>
#include <QRectF>
#include <QString>
#include <QVariantList>
#include <memory>

namespace KWin
{
class EffectWindow;
class OffscreenQuickScene;
class RenderTarget;
class RenderViewport;
class Output;

class FancyZonesEffect : public Effect
{
    Q_OBJECT
public:
    FancyZonesEffect();
    ~FancyZonesEffect() override;

    int requestedEffectChainPosition() const override { return 60; }
    void reconfigure(ReconfigureFlags flags) override; // re-read the zone config

protected:
    void paintScreen(const RenderTarget &renderTarget, const RenderViewport &viewport,
                     int mask, const QRegion &region, Output *screen) override;

private:
    struct Zone { QString name; double x, y, w, h; }; // percentages of the screen

    void loadZones();                 // from the JSON config, or built-in defaults
    QString configPath() const;       // $FZ_ZONES, else ~/.config/kwin-fancyzones/zones.json
    QVariantList zonesAsVariant() const; // for handing the zones to the overlay QML
    void hookWindow(EffectWindow *w);
    void updateGate();
    void setActive(bool active);
    void updateHighlight();
    void ensureOverlay();
    void pushHighlight();
    QRectF rectFor(const Zone &z) const;
    QRectF selectionRect() const;          // bounding box of the selected zones
    int pick(const QPointF &cursor) const; // nearest-center among zones containing cursor; -1 if none

    QList<Zone> m_zones;
    Qt::KeyboardModifiers m_mods = Qt::NoModifier;
    EffectWindow *m_movingWindow = nullptr;
    bool m_active = false;
    QList<int> m_selection;                 // indices of highlighted/selected zones (span)
    QPointF m_cursor;
    std::unique_ptr<OffscreenQuickScene> m_overlay;
    bool m_captured = false;
};

} // namespace KWin
