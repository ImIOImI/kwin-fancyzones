#include "fancyzoneseffect.h"

#include <effect/effecthandler.h>
#include <effect/effectwindow.h>

#include <QDebug>

namespace KWin
{

static void hookWindow(EffectWindow *w)
{
    if (!w) {
        return;
    }
    QObject::connect(w, &EffectWindow::windowStartUserMovedResized, effects, [](EffectWindow *win) {
        qInfo() << "[fzeffect] MOVE START" << win->caption();
    });
    QObject::connect(w, &EffectWindow::windowFinishUserMovedResized, effects, [](EffectWindow *win) {
        qInfo() << "[fzeffect] MOVE FINISH" << win->caption();
    });
}

FancyZonesEffect::FancyZonesEffect()
{
    // The capability scripts lack: live pointer + keyboard-modifier state.
    // mouseChanged is connection-tracked in KWin 6 — connecting enables delivery.
    connect(effects, &EffectsHandler::mouseChanged, this,
            [](const QPointF &pos, const QPointF &, Qt::MouseButtons buttons, Qt::MouseButtons,
               Qt::KeyboardModifiers mods, Qt::KeyboardModifiers) {
                qInfo().noquote() << "[fzeffect] mouseChanged pos=" << pos.x() << "," << pos.y()
                                  << "buttons=" << int(buttons) << "mods=" << int(mods)
                                  << "shift=" << bool(mods & Qt::ShiftModifier);
            });

    connect(effects, &EffectsHandler::windowAdded, this, [](EffectWindow *w) { hookWindow(w); });
    const auto windows = effects->stackingOrder();
    for (EffectWindow *w : windows) {
        hookWindow(w);
    }

    qInfo() << "[fzeffect] loaded";
}

FancyZonesEffect::~FancyZonesEffect() = default;

bool FancyZonesEffect::supported()
{
    return true;
}

KWIN_EFFECT_FACTORY(FancyZonesEffect, "metadata.json")

} // namespace KWin

#include "fancyzoneseffect.moc"
