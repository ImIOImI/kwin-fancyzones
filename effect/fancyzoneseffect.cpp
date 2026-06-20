#include "fancyzoneseffect.h"

#include <effect/effecthandler.h>
#include <effect/effectwindow.h>

#include <QDebug>

namespace KWin
{

FancyZonesEffect::FancyZonesEffect()
{
    // Track live keyboard-modifier state (connection-tracked in KWin 6). While a
    // move is in progress, re-evaluate the gate so Shift can be pressed/released
    // mid-drag.
    connect(effects, &EffectsHandler::mouseChanged, this,
            [this](const QPointF &, const QPointF &, Qt::MouseButtons, Qt::MouseButtons,
                   Qt::KeyboardModifiers mods, Qt::KeyboardModifiers) {
                m_mods = mods;
                if (m_movingWindow) {
                    updateGate();
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
        m_movingWindow = nullptr;
        setActive(false);
    });
}

// The gate: active iff a move is in progress AND Shift is held.
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
    qInfo().noquote() << "[fzeffect] overlay" << (m_active ? "SHOWN" : "hidden");
    // TODO(v0.5): show/hide the QuickSceneEffect zone overlay here.
}

bool FancyZonesEffect::supported()
{
    return true;
}

KWIN_EFFECT_FACTORY(FancyZonesEffect, "metadata.json")

} // namespace KWin

#include "fancyzoneseffect.moc"
