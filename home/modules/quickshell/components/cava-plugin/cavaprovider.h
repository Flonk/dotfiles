#pragma once

#include <QObject>
#include <QVector>
#include <QTimer>
#include <qqmlintegration.h>
#include "audiocollector.h"

struct cava_plan; // Forward declaration

namespace cava_plugin {

class CavaProvider : public QObject {
    Q_OBJECT
    QML_ELEMENT
    
    Q_PROPERTY(int bars READ bars WRITE setBars NOTIFY barsChanged)
    Q_PROPERTY(QVector<double> values READ values NOTIFY valuesChanged)
    
public:
    explicit CavaProvider(QObject* parent = nullptr);
    explicit CavaProvider(AudioSource source, QObject* parent = nullptr);
    ~CavaProvider();
    
    int bars() const { return m_bars; }
    void setBars(int bars);
    
    QVector<double> values() const { return m_values; }

signals:
    void barsChanged();
    void valuesChanged();

private slots:
    void processAudio();

private:
    void initCava();
    void cleanupCava();
    void applyMonstercatFilter(double* data, int size);
    
    int m_bars = 20;
    QVector<double> m_values;
    QTimer* m_timer;
    AudioSource m_audioSource = AudioSource::SystemAudio;
    
    // Audio collector for this provider
    AudioCollector* m_audioCollector = nullptr;
    
    // Cava related
    struct cava_plan* m_plan = nullptr;
    double* m_input_buffer = nullptr;
    double* m_output_buffer = nullptr;
    
    bool m_initialized = false;
};

} // namespace cava_plugin