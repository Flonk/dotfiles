#include "quickmilk.h"

#include <QDebug>
#include <QtGlobal>
#include <algorithm>
#include <cmath>

namespace quickmilk {

QuickmilkVisualizer::QuickmilkVisualizer(QObject* parent)
    : QuickmilkVisualizer(AudioSource::SystemAudio, parent) {}

QuickmilkVisualizer::QuickmilkVisualizer(AudioSource source, QObject* parent)
    : QObject(parent)
    , m_values(m_bars, 0.0)
    , m_noiseReduction(0.3)
    , m_audioSource(source) {

    m_inputBuffer = new float[ac::CHUNK_SIZE];
    setupAnalyzer();

    m_audioCollector = new AudioCollector(source, this);
    connect(m_audioCollector, &AudioCollector::dataAvailable,
            this, &QuickmilkVisualizer::processAudio, Qt::QueuedConnection);

    m_audioCollector->start();
}

QuickmilkVisualizer::~QuickmilkVisualizer() {
    if (m_audioCollector) {
        m_audioCollector->stop();
    }
    delete[] m_inputBuffer;
}

void QuickmilkVisualizer::setBars(int bars) {
    if (bars <= 0) {
        qWarning() << "QuickmilkVisualizer: bars must be greater than 0";
        bars = 1;
    }

    if (m_bars == bars) {
        return;
    }

    m_bars = bars;
    m_values.resize(m_bars, 0.0);
    m_effects.reset(m_bars);
    setupAnalyzer();

    emit barsChanged();
    emit valuesChanged();
}

void QuickmilkVisualizer::setNoiseReduction(double noiseReduction) {
    noiseReduction = std::clamp(noiseReduction, 0.0, 1.0);
    if (qFuzzyCompare(m_noiseReduction, noiseReduction)) {
        return;
    }

    m_noiseReduction = noiseReduction;
    emit noiseReductionChanged();
}

void QuickmilkVisualizer::setEnableMonstercatFilter(bool enable) {
    if (m_enableMonstercatFilter == enable) {
        return;
    }

    m_enableMonstercatFilter = enable;
    emit enableMonstercatFilterChanged();
}

void QuickmilkVisualizer::setMinFrequency(double value) {
    value = std::clamp(value, 1.0, m_maxFrequency);
    if (qFuzzyCompare(m_minFrequency, value)) {
        return;
    }

    m_minFrequency = value;
    configureAnalyzer();
    emit minFrequencyChanged();
}

void QuickmilkVisualizer::setMaxFrequency(double value) {
    value = std::clamp(value, m_minFrequency, 48000.0);
    if (qFuzzyCompare(m_maxFrequency, value)) {
        return;
    }

    m_maxFrequency = value;
    configureAnalyzer();
    emit maxFrequencyChanged();
}

void QuickmilkVisualizer::setDynamicFalloff(double value) {
    value = std::clamp(value, 0.0, 0.9999);
    if (qFuzzyCompare(m_dynamicFalloff, value)) {
        return;
    }

    m_dynamicFalloff = value;
    configureAnalyzer();
    emit dynamicFalloffChanged();
}

void QuickmilkVisualizer::setDynamicRise(double value) {
    value = std::clamp(value, 0.0, 1.0);
    if (qFuzzyCompare(m_dynamicRise, value)) {
        return;
    }

    m_dynamicRise = value;
    configureAnalyzer();
    emit dynamicRiseChanged();
}

void QuickmilkVisualizer::setAutoGainFloor(double value) {
    value = std::clamp(value, 1e-4, 10.0);
    if (qFuzzyCompare(m_autoGainFloor, value)) {
        return;
    }

    m_autoGainFloor = value;
    configureAnalyzer();
    emit autoGainFloorChanged();
}

void QuickmilkVisualizer::setSmoothingAlpha(double value) {
    value = std::clamp(value, 0.0, 1.0);
    if (qFuzzyCompare(m_effects.smoothingAlpha(), value)) {
        return;
    }

    m_effects.setSmoothingAlpha(value);
    emit smoothingAlphaChanged();
}

void QuickmilkVisualizer::setGravityDecay(double value) {
    value = std::clamp(value, 0.0, 1.0);
    if (qFuzzyCompare(m_effects.gravityDecay(), value)) {
        return;
    }

    m_effects.setGravityDecay(value);
    emit gravityDecayChanged();
}

void QuickmilkVisualizer::setNoiseFloorMinDecay(double value) {
    double clamped = std::clamp(value, 0.0, m_effects.noiseFloorMaxDecay());
    if (qFuzzyCompare(m_effects.noiseFloorMinDecay(), clamped)) {
        return;
    }

    m_effects.setNoiseFloorDecayRange(clamped, m_effects.noiseFloorMaxDecay());
    emit noiseFloorMinDecayChanged();
}

void QuickmilkVisualizer::setNoiseFloorMaxDecay(double value) {
    double clamped = std::clamp(value, m_effects.noiseFloorMinDecay(), 1.0);
    if (qFuzzyCompare(m_effects.noiseFloorMaxDecay(), clamped)) {
        return;
    }

    m_effects.setNoiseFloorDecayRange(m_effects.noiseFloorMinDecay(), clamped);
    emit noiseFloorMaxDecayChanged();
}

void QuickmilkVisualizer::setNoiseFloorMinRise(double value) {
    double clamped = std::max(0.0, std::min(value, m_effects.noiseFloorMaxRise()));
    if (qFuzzyCompare(m_effects.noiseFloorMinRise(), clamped)) {
        return;
    }

    m_effects.setNoiseFloorRiseRange(clamped, m_effects.noiseFloorMaxRise());
    emit noiseFloorMinRiseChanged();
}

void QuickmilkVisualizer::setNoiseFloorMaxRise(double value) {
    double clamped = std::max(value, m_effects.noiseFloorMinRise());
    if (qFuzzyCompare(m_effects.noiseFloorMaxRise(), clamped)) {
        return;
    }

    m_effects.setNoiseFloorRiseRange(m_effects.noiseFloorMinRise(), clamped);
    emit noiseFloorMaxRiseChanged();
}

void QuickmilkVisualizer::setNoiseFloorClamp(double value) {
    value = std::max(0.0, value);
    if (qFuzzyCompare(m_effects.noiseFloorClamp(), value)) {
        return;
    }

    m_effects.setNoiseFloorClamp(value);
    emit noiseFloorClampChanged();
}

void QuickmilkVisualizer::processAudio() {
    if (!m_audioCollector || !m_analyzer) {
        return;
    }

    const size_t samplesRead = m_audioCollector->readChunk(m_inputBuffer);
    if (samplesRead == 0) {
        return;
    }

    const bool ready = m_analyzer->consume(m_inputBuffer, samplesRead, m_workingBars);
    if (!ready) {
        return;
    }

    m_effects.process(m_workingBars, m_noiseReduction, m_enableMonstercatFilter);

    QVector<double> newValues(m_bars);
    for (int i = 0; i < m_bars; ++i) {
        const double value = i < m_workingBars.size() ? m_workingBars[i] : 0.0;
        newValues[i] = std::clamp(value, 0.0, 1.0);
    }

    if (newValues != m_values) {
        m_values = newValues;
        emit valuesChanged();
    }
}

void QuickmilkVisualizer::setupAnalyzer() {
    if (!m_analyzer) {
        m_analyzer = std::make_unique<SpectrumAnalyzer>(m_bars, ac::SAMPLE_RATE);
    } else {
        m_analyzer->setBarCount(m_bars);
    }

    configureAnalyzer();
    m_workingBars.resize(m_bars);
    m_effects.reset(m_bars);
}

void QuickmilkVisualizer::configureAnalyzer() {
    if (!m_analyzer) {
        return;
    }

    m_analyzer->setSampleRate(ac::SAMPLE_RATE);
    m_analyzer->setBarCount(m_bars);
    m_analyzer->setFrequencyRange(m_minFrequency, m_maxFrequency);
    m_analyzer->setDynamicFalloff(m_dynamicFalloff);
    m_analyzer->setDynamicRise(m_dynamicRise);
    m_analyzer->setAutoGainFloor(m_autoGainFloor);
}

QuickmilkHub::QuickmilkHub(QObject* parent)
    : QObject(parent)
    , m_systemVisualizer(new QuickmilkVisualizer(AudioSource::SystemAudio, this))
    , m_microphoneVisualizer(new QuickmilkVisualizer(AudioSource::Microphone, this)) {
    m_systemVisualizer->setBars(m_maxBars);
    m_microphoneVisualizer->setBars(m_maxBars);
    m_systemVisualizer->setEnableMonstercatFilter(m_monstercatFilter);
    m_microphoneVisualizer->setEnableMonstercatFilter(m_monstercatFilter);
    m_systemVisualizer->setGravityDecay(m_gravityDecay);
    m_microphoneVisualizer->setGravityDecay(m_gravityDecay);
    emit systemVisualizerChanged();
    emit microphoneVisualizerChanged();
}

void QuickmilkHub::setMaxBars(int bars) {
    if (bars <= 0) {
        bars = 1;
    }
    if (m_maxBars == bars) {
        return;
    }
    m_maxBars = bars;
    if (m_systemVisualizer) {
        m_systemVisualizer->setBars(m_maxBars);
    }
    if (m_microphoneVisualizer) {
        m_microphoneVisualizer->setBars(m_maxBars);
    }
    emit maxBarsChanged();
}

void QuickmilkHub::setEnableMonstercatFilter(bool enabled) {
    if (m_monstercatFilter == enabled) {
        return;
    }
    m_monstercatFilter = enabled;
    if (m_systemVisualizer) {
        m_systemVisualizer->setEnableMonstercatFilter(enabled);
    }
    if (m_microphoneVisualizer) {
        m_microphoneVisualizer->setEnableMonstercatFilter(enabled);
    }
    emit enableMonstercatFilterChanged();
}

void QuickmilkHub::setGravityDecay(double value) {
    value = std::clamp(value, 0.0, 1.0);
    if (qFuzzyCompare(m_gravityDecay, value)) {
        return;
    }

    m_gravityDecay = value;
    if (m_systemVisualizer) {
        m_systemVisualizer->setGravityDecay(value);
    }
    if (m_microphoneVisualizer) {
        m_microphoneVisualizer->setGravityDecay(value);
    }
    emit gravityDecayChanged();
}

} // namespace quickmilk
