#include "fancyzoneseffect.h"

#include <effect/effecthandler.h>
#include <effect/effectwindow.h>
#include <window.h> // KWin::Window::moveResize (internal)

#include <QDebug>

namespace KWin
{

FancyZonesEffect::FancyZonesEffect()
{
    // Zone layout (percent of screen). May overlap — "focus" overlaps the middle column.
    m_zones = {
        { QStringLiteral("left"), 0, 0, 33.34, 100 },
        { QStringLiteral("middle"), 33.33, 0, 33.34, 100 },
        { QStringLiteral("right"), 66.66, 0, 33.34, 100 },
        { QStringLiteral("focus"), 30, 55, 40, 40 },
    };

    connect(effects, &EffectsHandler::mouseChanged, this,
            [this](const QPointF &pos, const QPointF &, Qt::MouseButtons, Qt::MouseButtons,
                   Qt::KeyboardModifiers mods, Qt::KeyboardModifiers) {
                m_mods = mods;
                m_cursor = pos;
                if (m_movingWindow) {
                    updateGate();
                    if (m_active) {
                        updateHighlight();
                    }
                }
            });

    connect(effects, &EffectsHandler::windowAdded, this, [this](EffectWindow *w) { hookWindow(w); });
    const auto windows = effects->stackingOrder();
    for (EffectWindow *w : windows) {
        hookWindow(w);
    }

    qInfo() << "[fzeffect] loaded";
}

FancyZonesEffect::~FancyZonesEffect() = default;

QRectF FancyZonesEffect::rectFor(const Zone &z) const
{
    const QRectF a = effects->virtualScreenGeometry();
    return QRectF(qRound(a.x() + z.x / 100.0 * a.width()),
                  qRound(a.y() + z.y / 100.0 * a.height()),
                  qRound(z.w / 100.0 * a.width()),
                  qRound(z.h / 100.0 * a.height()));
}

int FancyZonesEffect::pick(const QPointF &c) const
{
    int best = -1;
    double bestDist = 1e18;
    for (int i = 0; i < m_zones.size(); ++i) {
        const QRectF r = rectFor(m_zones[i]);
        if (r.contains(c)) {
            const QPointF ctr = r.center();
            const double d = (ctr.x() - c.x()) * (ctr.x() - c.x()) + (ctr.y() - c.y()) * (ctr.y() - c.y());
            if (d < bestDist) {
                bestDist = d;
                best = i;
            }
        }
    }
    return best;
}

void FancyZonesEffect::updateHighlight()
{
    const int idx = pick(m_cursor);
    if (idx != m_highlight) {
        m_highlight = idx;
        qInfo().noquote() << "[fzeffect] highlight" << (idx >= 0 ? m_zones[idx].name : QStringLiteral("none"));
    }
}

void FancyZonesEffect::updateGate()
{
    setActive(m_movingWindow != nullptr && (m_mods & Qt::ShiftModifier));
}

void FancyZonesEffect::setActive(bool active)
{
    if (active == m_active) {
        return;
    }
    m_active = active;
    qInfo().noquote() << "[fzeffect] overlay" << (active ? "SHOWN" : "hidden");
    if (active) {
        updateHighlight();
    } else {
        m_highlight = -1;
    }
}

void FancyZonesEffect::hookWindow(EffectWindow *w)
{
    if (!w) {
        return;
    }
    connect(w, &EffectWindow::windowStartUserMovedResized, this, [this](EffectWindow *win) {
        m_movingWindow = win;
        qInfo().noquote() << "[fzeffect] move start" << win->caption()
                          << "shift=" << bool(m_mods & Qt::ShiftModifier);
        updateGate();
    });
    connect(w, &EffectWindow::windowFinishUserMovedResized, this, [this](EffectWindow *win) {
        qInfo().noquote() << "[fzeffect] move finish" << win->caption();
        if (m_active) {
            const int idx = pick(m_cursor);
            if (idx >= 0 && win->window()) {
                const QRectF r = rectFor(m_zones[idx]);
                win->window()->moveResize(r);
                qInfo().noquote() << "[fzeffect] snapped to" << m_zones[idx].name << "target" << r;
            }
        }
        m_movingWindow = nullptr;
        setActive(false);
    });
}

KWIN_EFFECT_FACTORY(FancyZonesEffect, "metadata.json")

} // namespace KWin

#include "fancyzoneseffect.moc"
