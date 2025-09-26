#pragma once

#include <QObject>
#include <QVector>
#include <qqmlintegration.h>
#include "audiocollector.h"

struct cava_plan; // Forward declaration

namespace cava_plugin {

class CavaProvider : public QObject {
    Q_OBJECT
    QML_ELEMENT
    
    Q_PROPERTY(int bars READ bars WRITE setBars NOTIFY barsChanged)
    Q_PROPERTY(QVector<double> values READ values NOTIFY valuesChanged)
    Q_PROPERTY(double noiseReduction READ noiseReduction WRITE setNoiseReduction NOTIFY noiseReductionChanged)
    Q_PROPERTY(bool enableMonstercatFilter READ enableMonstercatFilter WRITE setEnableMonstercatFilter NOTIFY enableMonstercatFilterChanged)
    
public:
    explicit CavaProvider(QObject* parent = nullptr);
    explicit CavaProvider(AudioSource source, QObject* parent = nullptr);
    ~CavaProvider();
    
    int bars() const { return m_bars; }
    void setBars(int bars);
    
    double noiseReduction() const { return m_noiseReduction; }
    void setNoiseReduction(double noiseReduction);
    
    bool enableMonstercatFilter() const { return m_enableMonstercatFilter; }
    void setEnableMonstercatFilter(bool enable);
    
    QVector<double> values() const { return m_values; }

signals:
    void barsChanged();
    void valuesChanged();
    void noiseReductionChanged();
    void enableMonstercatFilterChanged();

private slots:
    void processAudio();

private:
    void initCava();
    void cleanupCava();
    void applyMonstercatFilter(double* data, int n);
    
    int m_bars = 40;
    double m_noiseReduction = 0.3;
    bool m_enableMonstercatFilter = false;
    QVector<double> m_values;
    AudioSource m_audioSource = AudioSource::SystemAudio;
    
    // Audio collector for this provider
    AudioCollector* m_audioCollector = nullptr;
    
    // Cava related
    struct cava_plan* m_plan = nullptr;
    float* m_input_buffer_f = nullptr;   // float buffer for audio input
    double* m_input_buffer_d = nullptr;  // double buffer for cava
    double* m_output_buffer = nullptr;
    
    bool m_initialized = false;
};

} // namespace cava_plugin