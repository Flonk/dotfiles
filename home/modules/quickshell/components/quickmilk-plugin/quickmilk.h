#pragma once

#include <QObject>
#include <QVector>
#include <QMetaType>
#include <memory>
#include <qqmlintegration.h>

#include "audiocollector.h"
#include "spectrumanalyzer.h"
#include "visualizereffects.h"

namespace quickmilk {

class QuickmilkVisualizer : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(QuickmilkVisualizer)
    QML_UNCREATABLE("Quickmilk visualizers are provided by the Quickmilk hub.")

    Q_PROPERTY(int bars READ bars WRITE setBars NOTIFY barsChanged)
    Q_PROPERTY(QVector<double> values READ values NOTIFY valuesChanged)
    Q_PROPERTY(double noiseReduction READ noiseReduction WRITE setNoiseReduction NOTIFY noiseReductionChanged)
    Q_PROPERTY(bool enableMonstercatFilter READ enableMonstercatFilter WRITE setEnableMonstercatFilter NOTIFY enableMonstercatFilterChanged)

    Q_PROPERTY(double minFrequency READ minFrequency WRITE setMinFrequency NOTIFY minFrequencyChanged)
    Q_PROPERTY(double maxFrequency READ maxFrequency WRITE setMaxFrequency NOTIFY maxFrequencyChanged)
    Q_PROPERTY(double dynamicFalloff READ dynamicFalloff WRITE setDynamicFalloff NOTIFY dynamicFalloffChanged)
    Q_PROPERTY(double dynamicRise READ dynamicRise WRITE setDynamicRise NOTIFY dynamicRiseChanged)
    Q_PROPERTY(double autoGainFloor READ autoGainFloor WRITE setAutoGainFloor NOTIFY autoGainFloorChanged)

    Q_PROPERTY(double smoothingAlpha READ smoothingAlpha WRITE setSmoothingAlpha NOTIFY smoothingAlphaChanged)
    Q_PROPERTY(double gravityDecay READ gravityDecay WRITE setGravityDecay NOTIFY gravityDecayChanged)

    Q_PROPERTY(double noiseFloorMinDecay READ noiseFloorMinDecay WRITE setNoiseFloorMinDecay NOTIFY noiseFloorMinDecayChanged)
    Q_PROPERTY(double noiseFloorMaxDecay READ noiseFloorMaxDecay WRITE setNoiseFloorMaxDecay NOTIFY noiseFloorMaxDecayChanged)
    Q_PROPERTY(double noiseFloorMinRise READ noiseFloorMinRise WRITE setNoiseFloorMinRise NOTIFY noiseFloorMinRiseChanged)
    Q_PROPERTY(double noiseFloorMaxRise READ noiseFloorMaxRise WRITE setNoiseFloorMaxRise NOTIFY noiseFloorMaxRiseChanged)
    Q_PROPERTY(double noiseFloorClamp READ noiseFloorClamp WRITE setNoiseFloorClamp NOTIFY noiseFloorClampChanged)

public:
    explicit QuickmilkVisualizer(QObject* parent = nullptr);
    explicit QuickmilkVisualizer(AudioSource source, QObject* parent = nullptr);
    ~QuickmilkVisualizer() override;

    int bars() const { return m_bars; }
    void setBars(int bars);

    QVector<double> values() const { return m_values; }

    double noiseReduction() const { return m_noiseReduction; }
    void setNoiseReduction(double noiseReduction);

    bool enableMonstercatFilter() const { return m_enableMonstercatFilter; }
    void setEnableMonstercatFilter(bool enable);

    double minFrequency() const { return m_minFrequency; }
    void setMinFrequency(double value);

    double maxFrequency() const { return m_maxFrequency; }
    void setMaxFrequency(double value);

    double dynamicFalloff() const { return m_dynamicFalloff; }
    void setDynamicFalloff(double value);

    double dynamicRise() const { return m_dynamicRise; }
    void setDynamicRise(double value);

    double autoGainFloor() const { return m_autoGainFloor; }
    void setAutoGainFloor(double value);

    double smoothingAlpha() const { return m_effects.smoothingAlpha(); }
    void setSmoothingAlpha(double value);

    double gravityDecay() const { return m_effects.gravityDecay(); }
    void setGravityDecay(double value);

    double noiseFloorMinDecay() const { return m_effects.noiseFloorMinDecay(); }
    void setNoiseFloorMinDecay(double value);

    double noiseFloorMaxDecay() const { return m_effects.noiseFloorMaxDecay(); }
    void setNoiseFloorMaxDecay(double value);

    double noiseFloorMinRise() const { return m_effects.noiseFloorMinRise(); }
    void setNoiseFloorMinRise(double value);

    double noiseFloorMaxRise() const { return m_effects.noiseFloorMaxRise(); }
    void setNoiseFloorMaxRise(double value);

    double noiseFloorClamp() const { return m_effects.noiseFloorClamp(); }
    void setNoiseFloorClamp(double value);

signals:
    void barsChanged();
    void valuesChanged();
    void noiseReductionChanged();
    void enableMonstercatFilterChanged();

    void minFrequencyChanged();
    void maxFrequencyChanged();
    void dynamicFalloffChanged();
    void dynamicRiseChanged();
    void autoGainFloorChanged();

    void smoothingAlphaChanged();
    void gravityDecayChanged();

    void noiseFloorMinDecayChanged();
    void noiseFloorMaxDecayChanged();
    void noiseFloorMinRiseChanged();
    void noiseFloorMaxRiseChanged();
    void noiseFloorClampChanged();

private slots:
    void processAudio();

private:
    void setupAnalyzer();
    void configureAnalyzer();

    int m_bars = 40;
    QVector<double> m_values;

    double m_noiseReduction = 0.3;
    bool m_enableMonstercatFilter = false;

    double m_minFrequency = 20.0;
    double m_maxFrequency = 20000.0;
    double m_dynamicFalloff = 0.995;
    double m_dynamicRise = 0.2;
    double m_autoGainFloor = 0.02;

    QVector<double> m_workingBars;

    AudioSource m_audioSource = AudioSource::SystemAudio;
    AudioCollector* m_audioCollector = nullptr;
    std::unique_ptr<SpectrumAnalyzer> m_analyzer;
    VisualizerEffects m_effects;
    float* m_inputBuffer = nullptr;
};

class QuickmilkHub : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(QuickmilkHub)

    Q_PROPERTY(int maxBars READ maxBars WRITE setMaxBars NOTIFY maxBarsChanged FINAL)
    Q_PROPERTY(bool enableMonstercatFilter READ enableMonstercatFilter WRITE setEnableMonstercatFilter NOTIFY enableMonstercatFilterChanged FINAL)
    Q_PROPERTY(double gravityDecay READ gravityDecay WRITE setGravityDecay NOTIFY gravityDecayChanged FINAL)
    Q_PROPERTY(QObject* systemVisualizer READ systemVisualizer NOTIFY systemVisualizerChanged FINAL)
    Q_PROPERTY(QObject* microphoneVisualizer READ microphoneVisualizer NOTIFY microphoneVisualizerChanged FINAL)

public:
    explicit QuickmilkHub(QObject* parent = nullptr);
    ~QuickmilkHub() override = default;

    int maxBars() const { return m_maxBars; }
    void setMaxBars(int bars);

    bool enableMonstercatFilter() const { return m_monstercatFilter; }
    void setEnableMonstercatFilter(bool enabled);

    double gravityDecay() const { return m_gravityDecay; }
    void setGravityDecay(double value);

    QObject* systemVisualizer() const { return m_systemVisualizer; }
    QObject* microphoneVisualizer() const { return m_microphoneVisualizer; }

    QuickmilkVisualizer* systemVisualizerTyped() const { return m_systemVisualizer; }
    QuickmilkVisualizer* microphoneVisualizerTyped() const { return m_microphoneVisualizer; }

signals:
    void maxBarsChanged();
    void enableMonstercatFilterChanged();
    void gravityDecayChanged();
    void systemVisualizerChanged();
    void microphoneVisualizerChanged();

private:
    QuickmilkVisualizer* m_systemVisualizer = nullptr;
    QuickmilkVisualizer* m_microphoneVisualizer = nullptr;
    int m_maxBars = 40;
    bool m_monstercatFilter = true;
    double m_gravityDecay = 0.97;
};

} // namespace quickmilk
