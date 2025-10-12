#include "datatexture.h"
#include <QtMath>
#include <algorithm>
#include <cmath>

#include <QColor>
#include <QMetaMethod>
#include <QQuickWindow>
#include <QSGImageNode>
#include <QSGSimpleTextureNode>
#include <QSGTexture>
#include "quickmilk.h"

namespace {

int clampToByte(double value) {
    if (value <= 0.0) {
        return 0;
    }
    if (value >= 1.0) {
        return 255;
    }
    return static_cast<int>(std::lround(value * 255.0));
}

} // namespace

namespace quickmilk {

QuickmilkDataTexture::QuickmilkDataTexture(QQuickItem* parent)
    : QQuickItem(parent) {
    setFlag(ItemHasContents, true);

    m_throttleTimer.setSingleShot(true);
    connect(&m_throttleTimer, &QTimer::timeout, this, [this]() {
        if (m_pendingRefresh) {
            performRefresh();
            const int interval = 1000 / std::max(1, m_maxFps);
            m_throttleTimer.start(interval);
        }
    });
}

QuickmilkDataTexture::~QuickmilkDataTexture() {
    if (m_systemConnection) {
        disconnect(m_systemConnection);
    }
    if (m_microphoneConnection) {
        disconnect(m_microphoneConnection);
    }
    if (m_volumeWidget) {
        disconnect(m_volumeConnection);
    }
    if (m_hubSystemConnection) {
        disconnect(m_hubSystemConnection);
    }
    if (m_hubMicrophoneConnection) {
        disconnect(m_hubMicrophoneConnection);
    }
    if (m_hubMaxBarsConnection) {
        disconnect(m_hubMaxBarsConnection);
    }
}

void QuickmilkDataTexture::componentComplete() {
    QQuickItem::componentComplete();
    performRefresh();
}

void QuickmilkDataTexture::setVolumeWidget(QObject* widget) {
    if (m_volumeWidget == widget) {
        return;
    }
    if (m_volumeWidget) {
        disconnect(m_volumeConnection);
    }
    m_volumeWidget = widget;
    if (m_volumeWidget) {
        const int signalIndex = m_volumeWidget->metaObject()->indexOfSignal("volumeChanged()");
        if (signalIndex != -1) {
            QMetaMethod signal = m_volumeWidget->metaObject()->method(signalIndex);
            const int slotIndex = metaObject()->indexOfSlot("handleVolumeChanged()");
            if (slotIndex != -1) {
                QMetaMethod slot = metaObject()->method(slotIndex);
                m_volumeConnection = connect(m_volumeWidget, signal, this, slot);
            }
        }
        m_volume = m_volumeWidget->property("volume").toDouble();
    }
    emit volumeWidgetChanged();
    performRefresh();
}

void QuickmilkDataTexture::setMaxBars(int bars) {
    applyMaxBars(bars, true);
}

void QuickmilkDataTexture::applyMaxBars(int bars, bool propagateToHub) {
    if (bars <= 0) {
        bars = 1;
    }
    if (m_maxBars == bars) {
        return;
    }

    m_maxBars = bars;
    if (propagateToHub && m_quickmilk) {
        m_quickmilk->setMaxBars(m_maxBars);
    }

    emit maxBarsChanged();
    performRefresh();
}

void QuickmilkDataTexture::setMaxFps(int fps) {
    if (fps <= 0) {
        fps = 1;
    }
    if (m_maxFps == fps) {
        return;
    }
    m_maxFps = fps;
    emit maxFpsChanged();
    performRefresh();
}

void QuickmilkDataTexture::setHubObject(QObject* hub) {
    setHub(qobject_cast<QuickmilkHub*>(hub));
}

void QuickmilkDataTexture::setHub(QuickmilkHub* hub) {
    if (m_quickmilk == hub) {
        return;
    }

    if (m_hubSystemConnection) {
        disconnect(m_hubSystemConnection);
        m_hubSystemConnection = {};
    }
    if (m_hubMicrophoneConnection) {
        disconnect(m_hubMicrophoneConnection);
        m_hubMicrophoneConnection = {};
    }
    if (m_hubMaxBarsConnection) {
        disconnect(m_hubMaxBarsConnection);
        m_hubMaxBarsConnection = {};
    }

    m_quickmilk = hub;

    if (m_quickmilk) {
    m_hubSystemConnection = connect(m_quickmilk, &QuickmilkHub::systemVisualizerChanged,
                    this, &QuickmilkDataTexture::handleVisualizersUpdated);
    m_hubMicrophoneConnection = connect(m_quickmilk, &QuickmilkHub::microphoneVisualizerChanged,
                        this, &QuickmilkDataTexture::handleVisualizersUpdated);
        m_hubMaxBarsConnection = connect(m_quickmilk, &QuickmilkHub::maxBarsChanged,
                                         this, &QuickmilkDataTexture::handleHubMaxBarsChanged);
        applyMaxBars(m_quickmilk->maxBars(), false);
    }

    handleVisualizersUpdated();
    emit hubChanged();
}

void QuickmilkDataTexture::setDragging(bool dragging) {
    if (m_dragging == dragging) {
        return;
    }
    m_dragging = dragging;
    emit draggingChanged();
    scheduleRefresh();
}

void QuickmilkDataTexture::handleValuesChanged() {
    scheduleRefresh();
}

void QuickmilkDataTexture::handleVolumeChanged() {
    if (m_volumeWidget) {
        m_volume = m_volumeWidget->property("volume").toDouble();
    }
    scheduleRefresh();
}

void QuickmilkDataTexture::scheduleRefresh() {
    if (!isComponentComplete()) {
        return;
    }

    if (!m_throttleTimer.isActive()) {
        performRefresh();
        const int interval = 1000 / std::max(1, m_maxFps);
        m_throttleTimer.start(interval);
    } else {
        m_pendingRefresh = true;
    }
}

void QuickmilkDataTexture::handleVisualizersUpdated() {
    updateVisualizerConnections();
    scheduleRefresh();
}

void QuickmilkDataTexture::handleHubMaxBarsChanged() {
    if (!m_quickmilk) {
        return;
    }
    applyMaxBars(m_quickmilk->maxBars(), false);
}

void QuickmilkDataTexture::updateVisualizerConnections() {
    QuickmilkVisualizer* newSystem = m_quickmilk ? m_quickmilk->systemVisualizerTyped() : nullptr;
    QuickmilkVisualizer* newMicrophone = m_quickmilk ? m_quickmilk->microphoneVisualizerTyped() : nullptr;

    if (newSystem != m_systemProvider) {
        if (m_systemConnection) {
            disconnect(m_systemConnection);
            m_systemConnection = {};
        }
        m_systemProvider = newSystem;
        if (m_systemProvider) {
            m_systemConnection = connect(m_systemProvider, &QuickmilkVisualizer::valuesChanged,
                                         this, &QuickmilkDataTexture::handleValuesChanged);
        }
        emit systemVisualizerChanged();
    }

    if (newMicrophone != m_microphoneProvider) {
        if (m_microphoneConnection) {
            disconnect(m_microphoneConnection);
            m_microphoneConnection = {};
        }
        m_microphoneProvider = newMicrophone;
        if (m_microphoneProvider) {
            m_microphoneConnection = connect(m_microphoneProvider, &QuickmilkVisualizer::valuesChanged,
                                             this, &QuickmilkDataTexture::handleValuesChanged);
        }
        emit microphoneVisualizerChanged();
    }
}

void QuickmilkDataTexture::performRefresh() {
    m_pendingRefresh = false;

    m_systemValues = m_systemProvider ? m_systemProvider->values() : QVector<double>();
    m_microphoneValues = m_microphoneProvider ? m_microphoneProvider->values() : QVector<double>();

    int count = std::max(m_systemValues.size(), m_microphoneValues.size());
    if (m_maxBars > 0) {
        count = std::min(count, m_maxBars);
    }
    if (count <= 0) {
        count = 1;
    }

    if (m_barCount != count) {
        m_barCount = count;
        setImplicitWidth(count);
        setImplicitHeight(1);
        emit barCountChanged();
    }

    rebuildImage(count);

    const uchar volumeEncoded = encodeVolumeChannel();

    uchar* line = m_image.bits();
    for (int i = 0; i < count; ++i) {
        const double sys = i < m_systemValues.size() ? m_systemValues.at(i) : 0.0;
        const double mic = i < m_microphoneValues.size() ? m_microphoneValues.at(i) : 0.0;
        const int r = clampToByte(sys);
        const int g = clampToByte(mic);
        line[i * 4 + 0] = static_cast<uchar>(r);
        line[i * 4 + 1] = static_cast<uchar>(g);
        line[i * 4 + 2] = volumeEncoded;
        line[i * 4 + 3] = 255;
    }

    markTextureDirty();
}

void QuickmilkDataTexture::rebuildImage(int width) {
    if (m_image.width() == width && m_image.height() == 1) {
        return;
    }
    m_image = QImage(width, 1, QImage::Format_RGBA8888);
    m_image.fill(Qt::transparent);
}

uchar QuickmilkDataTexture::encodeVolumeChannel() const {
    const double volume = std::clamp(m_volume, 0.0, 1.0);
    const int base = static_cast<int>(std::round(volume * 127.0));
    if (m_dragging) {
        return static_cast<uchar>(std::min(base + 128, 255));
    }
    return static_cast<uchar>(base);
}

void QuickmilkDataTexture::markTextureDirty() {
    m_textureDirty = true;
    update();
}

QSGNode* QuickmilkDataTexture::updatePaintNode(QSGNode* node, UpdatePaintNodeData*) {
    QSGSimpleTextureNode* textureNode = static_cast<QSGSimpleTextureNode*>(node);
    if (!window()) {
        delete textureNode;
        return nullptr;
    }

    if (!textureNode) {
        textureNode = new QSGSimpleTextureNode();
        textureNode->setOwnsTexture(true);
    }

    if (m_textureDirty) {
        m_textureDirty = false;
        QSGTexture* texture = window()->createTextureFromImage(m_image);
        textureNode->setTexture(texture);
        textureNode->setRect(boundingRect().isEmpty() ? QRectF(0, 0, m_image.width(), 1) : boundingRect());
    }

    return textureNode;
}

} // namespace quickmilk
