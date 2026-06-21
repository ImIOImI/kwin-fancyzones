#include "fancyzoneseffect.h"

#include <effect/effecthandler.h>
#include <effect/effectwindow.h>
#include <effect/offscreenquickview.h>
#include <window.h> // KWin::Window::moveResize (internal)

#include <core/rendertarget.h>
#include <core/renderviewport.h>
#include <opengl/glshader.h>
#include <opengl/glshadermanager.h>
#include <opengl/gltexture.h>

#include <QQuickItem>
#include <QImage>
#include <QMatrix4x4>
#include <QPainter>
#include <QDebug>
#include <QUrl>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QVariantList>
#include <QVariantMap>

#include <epoxy/gl.h>

namespace KWin
{

FancyZonesEffect::FancyZonesEffect()
{
    loadZones();

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

void FancyZonesEffect::reconfigure(ReconfigureFlags)
{
    loadZones();
    if (m_overlay && m_overlay->rootItem()) {
        m_overlay->rootItem()->setProperty("zones", zonesAsVariant());
    }
}

QString FancyZonesEffect::configPath() const
{
    const QByteArray override = qgetenv("FZ_ZONES");
    if (!override.isEmpty()) {
        return QString::fromLocal8Bit(override);
    }
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
        + QStringLiteral("/kwin-fancyzones/zones.json");
}

// Read zones from the JSON config; fall back to the built-in default layout.
void FancyZonesEffect::loadZones()
{
    m_zones.clear();
    const QString path = configPath();
    QFile f(path);
    if (f.open(QIODevice::ReadOnly)) {
        const QJsonArray arr = QJsonDocument::fromJson(f.readAll()).object().value(QStringLiteral("zones")).toArray();
        for (const QJsonValue &v : arr) {
            const QJsonObject o = v.toObject();
            m_zones.append(Zone{ o.value(QStringLiteral("name")).toString(),
                                 o.value(QStringLiteral("x")).toDouble(),
                                 o.value(QStringLiteral("y")).toDouble(),
                                 o.value(QStringLiteral("width")).toDouble(),
                                 o.value(QStringLiteral("height")).toDouble() });
        }
    }
    if (!m_zones.isEmpty()) {
        qInfo().noquote() << "[fzeffect] loaded" << m_zones.size() << "zones from" << path;
        return;
    }
    // Built-in default: 3-column grid + a lower-center "focus" zone overlapping the middle.
    m_zones = {
        { QStringLiteral("left"), 0, 0, 33.34, 100 },
        { QStringLiteral("middle"), 33.33, 0, 33.34, 100 },
        { QStringLiteral("right"), 66.66, 0, 33.34, 100 },
        { QStringLiteral("focus"), 30, 55, 40, 40 },
    };
    qInfo().noquote() << "[fzeffect] using default zones (no config at" << path << ")";
}

QVariantList FancyZonesEffect::zonesAsVariant() const
{
    QVariantList list;
    for (const Zone &z : m_zones) {
        list.append(QVariantMap{ { QStringLiteral("name"), z.name },
                                 { QStringLiteral("x"), z.x },
                                 { QStringLiteral("y"), z.y },
                                 { QStringLiteral("w"), z.w },
                                 { QStringLiteral("h"), z.h } });
    }
    return list;
}

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

void FancyZonesEffect::ensureOverlay()
{
    if (!m_overlay) {
        m_overlay = std::make_unique<OffscreenQuickScene>(OffscreenQuickView::ExportMode::Image, true);
        m_overlay->setSource(QUrl(QStringLiteral("qrc:/fancyzones/overlay.qml")));
        connect(m_overlay.get(), &OffscreenQuickView::repaintNeeded, this, []() { effects->addRepaintFull(); });
    }
    // Feed the configured zones to the overlay QML (single source of truth = the config).
    if (m_overlay->rootItem()) {
        m_overlay->rootItem()->setProperty("zones", zonesAsVariant());
    }
    m_overlay->setGeometry(effects->virtualScreenGeometry());
    m_overlay->show();
}

void FancyZonesEffect::pushHighlight(int idx)
{
    if (m_overlay && m_overlay->rootItem()) {
        m_overlay->rootItem()->setProperty("highlighted", idx);
        m_overlay->update();
        effects->addRepaintFull();
    }
}

void FancyZonesEffect::updateHighlight()
{
    const int idx = pick(m_cursor);
    if (idx != m_highlight) {
        m_highlight = idx;
        qInfo().noquote() << "[fzeffect] highlight" << (idx >= 0 ? m_zones[idx].name : QStringLiteral("none"));
    }
    pushHighlight(idx);
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
        m_captured = false;
        ensureOverlay();
        updateHighlight();
    } else {
        m_highlight = -1;
    }
    effects->addRepaintFull();
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

void FancyZonesEffect::paintScreen(const RenderTarget &renderTarget, const RenderViewport &viewport,
                                   int mask, const QRegion &region, Output *screen)
{
    effects->paintScreen(renderTarget, viewport, mask, region, screen);

    if (!m_active || !m_overlay) {
        return;
    }
    m_overlay->update(); // render the QML now (GL context is current here)
    const QImage img = m_overlay->bufferAsImage();
    if (img.isNull()) {
        return;
    }

    // Capture the overlay render for headless verification (set FZ_CAPTURE=path).
    if (!m_captured) {
        m_captured = true;
        const QByteArray path = qgetenv("FZ_CAPTURE");
        if (!path.isEmpty()) {
            if (img.save(QString::fromLocal8Bit(path))) {
                qInfo().noquote() << "[fzeffect] captured overlay" << img.size() << "->" << QString::fromLocal8Bit(path);
            } else {
                qInfo() << "[fzeffect] overlay capture failed";
            }
        }
    }

    // QPainter (software) compositing path — e.g. KWin nested in WSLg, which only
    // offers QPainter. The render target wraps a QImage we can draw onto directly.
    if (QImage *target = renderTarget.image()) {
        QPainter p(target);
        if (p.isActive()) {
            p.setRenderHint(QPainter::SmoothPixmapTransform);
            p.drawImage(viewport.mapToRenderTarget(QRectF(m_overlay->geometry())), img);
            qInfo() << "[fzeffect] overlay painted (QPainter)";
        }
        return;
    }

    // OpenGL compositing path. Upload the rendered image to a texture and blit it
    // (premultiplied alpha) — works under both software GL and real GPUs.
    std::unique_ptr<GLTexture> tex = GLTexture::upload(img);
    if (!tex) {
        return;
    }
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    ShaderBinder binder(ShaderTrait::MapTexture | ShaderTrait::Modulate);
    binder.shader()->setUniform(GLShader::Mat4Uniform::ModelViewProjectionMatrix, viewport.projectionMatrix());
    tex->bind();
    tex->render(QSizeF(m_overlay->geometry().size()));
    tex->unbind();
    glDisable(GL_BLEND);
}

KWIN_EFFECT_FACTORY(FancyZonesEffect, "metadata.json")

} // namespace KWin

#include "fancyzoneseffect.moc"
