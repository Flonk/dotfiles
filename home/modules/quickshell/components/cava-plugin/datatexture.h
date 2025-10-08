#pragma once

#include <QImage>
#include <QVector>
#include <QQuickItem>
#include <QTimer>
#include <QMetaObject>
#include <qqmlintegration.h>

class QSGTexture;

namespace cava_plugin {

class CavaProvider;

class CavaDataTexture : public QQuickItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QObject* volumeWidget READ volumeWidget WRITE setVolumeWidget NOTIFY volumeWidgetChanged)
    Q_PROPERTY(int maxBars READ maxBars WRITE setMaxBars NOTIFY maxBarsChanged)
    Q_PROPERTY(int maxFps READ maxFps WRITE setMaxFps NOTIFY maxFpsChanged)
    Q_PROPERTY(int barCount READ barCount NOTIFY barCountChanged)
    Q_PROPERTY(bool dragging READ dragging WRITE setDragging NOTIFY draggingChanged)
    Q_PROPERTY(bool monstercatFilter READ monstercatFilter WRITE setMonstercatFilter NOTIFY monstercatFilterChanged)

public:
    explicit CavaDataTexture(QQuickItem* parent = nullptr);
    ~CavaDataTexture() override;

    QObject* volumeWidget() const { return m_volumeWidget; }
    void setVolumeWidget(QObject* widget);

    int maxBars() const { return m_maxBars; }
    void setMaxBars(int bars);

    int maxFps() const { return m_maxFps; }
    void setMaxFps(int fps);

    int barCount() const { return m_barCount; }

    bool dragging() const { return m_dragging; }
    void setDragging(bool dragging);

    bool monstercatFilter() const { return m_monstercatFilter; }
    void setMonstercatFilter(bool enabled);

signals:
    void volumeWidgetChanged();
    void maxBarsChanged();
    void maxFpsChanged();
    void barCountChanged();
    void draggingChanged();
    void monstercatFilterChanged();

protected:
    QSGNode* updatePaintNode(QSGNode* node, UpdatePaintNodeData* data) override;

    void componentComplete() override;

private:
    void scheduleRefresh();
    void performRefresh();
    void rebuildImage(int width);
    uchar encodeVolumeChannel() const;
    void markTextureDirty();

private slots:
    void handleValuesChanged();
    void handleVolumeChanged();

private:
    CavaProvider* m_systemProvider = nullptr;
    CavaProvider* m_microphoneProvider = nullptr;
    QObject* m_volumeWidget = nullptr;
    QMetaObject::Connection m_systemConnection;
    QMetaObject::Connection m_microphoneConnection;
    QMetaObject::Connection m_volumeConnection;

    int m_maxBars = 40;
    int m_maxFps = 30;
    int m_barCount = 1;
    bool m_dragging = false;
    bool m_monstercatFilter = true;

    QVector<double> m_systemValues;
    QVector<double> m_microphoneValues;
    double m_volume = 0.5;

    QImage m_image;
    bool m_textureDirty = false;
    bool m_pendingRefresh = false;

    QTimer m_throttleTimer;
};

} // namespace cava_plugin
