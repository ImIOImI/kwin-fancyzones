#include "fancyzoneseffect.h"

#include <effect/effecthandler.h>
#include <effect/effectwindow.h>

#include <QDebug>
#include <QUrl>

namespace KWin
{

FancyZonesEffect::FancyZonesEffect()
{
    setSource(QUrl(QStringLiteral("qrc:/fancyzones/overlay.qml")));

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
    setRunning(m_active);
}

bool FancyZonesEffect::supported()
{
    return effects->isOpenGLCompositing();
}

KWIN_EFFECT_FACTORY(FancyZonesEffect, "metadata.json")

} // namespace KWin

#include "fancyzoneseffect.moc"
