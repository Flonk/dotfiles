#include "cavaprovider.h"
#include "audiocollector.h"
#include <QDebug>
#include <cava/cavacore.h>
#include <cmath>
#include <algorithm>
#include <vector>

namespace cava_plugin {

CavaProvider::CavaProvider(QObject* parent)
    : CavaProvider(AudioSource::SystemAudio, parent) {}

CavaProvider::CavaProvider(AudioSource source, QObject* parent)
    : QObject(parent)
    , m_audioSource(source)
{
    m_values.resize(m_bars, 0.0);
    m_input_buffer_f = new float[ac::CHUNK_SIZE];
    m_input_buffer_d = new double[ac::CHUNK_SIZE];
    
    // Create audio collector for specified source
    m_audioCollector = new AudioCollector(source, this);
    
    // Connect audio-driven processing (queued connection for thread safety)
    connect(m_audioCollector, &AudioCollector::dataAvailable, 
            this, &CavaProvider::processAudio, Qt::QueuedConnection);
    
    initCava();
    
    // Start audio collection
    m_audioCollector->start();
}

CavaProvider::~CavaProvider() {
    if (m_audioCollector) {
        m_audioCollector->stop();
    }
    cleanupCava();
    delete[] m_input_buffer_f;
    delete[] m_input_buffer_d;
}

void CavaProvider::setBars(int bars) {
    if (bars <= 0) {
        qWarning() << "CavaProvider: bars must be greater than 0";
        bars = 1;
    }
    
    if (m_bars == bars) return;
    
    m_bars = bars;
    m_values.resize(bars, 0.0);
    
    // Reinitialize cava with new bar count
    cleanupCava();
    initCava();
    
    emit barsChanged();
    emit valuesChanged();
}

void CavaProvider::setNoiseReduction(double noiseReduction) {
    if (noiseReduction < 0.0) noiseReduction = 0.0;
    if (noiseReduction > 1.0) noiseReduction = 1.0;
    
    if (qFuzzyCompare(m_noiseReduction, noiseReduction)) return;
    
    m_noiseReduction = noiseReduction;
    
    // Reinitialize cava with new noise reduction
    cleanupCava();
    initCava();
    
    emit noiseReductionChanged();
}

void CavaProvider::setEnableMonstercatFilter(bool enable) {
    if (m_enableMonstercatFilter == enable) return;
    
    m_enableMonstercatFilter = enable;
    emit enableMonstercatFilterChanged();
}



void CavaProvider::processAudio() {
    if (!m_audioCollector || !m_plan || !m_initialized) return;
    
    // Read audio data from collector as float
    const size_t samples_read = m_audioCollector->readChunk(m_input_buffer_f);
    
    if (samples_read == 0) return;
    
    // Convert float to double in tight loop (vectorized by compiler with -O3)
    for (int i = 0; i < ac::CHUNK_SIZE; ++i) {
        m_input_buffer_d[i] = static_cast<double>(m_input_buffer_f[i]);
    }
    
    // Process audio through cava
    cava_execute(m_input_buffer_d, static_cast<int>(samples_read), m_output_buffer, m_plan);
    
    // Apply monstercat smoothing filter if enabled
    if (m_enableMonstercatFilter) {
        applyMonstercatFilter(m_output_buffer, m_bars);
    }
    
    // Update values
    QVector<double> newValues(m_bars);
    for (int i = 0; i < m_bars; ++i) {
        newValues[i] = std::max(0.0, std::min(1.0, m_output_buffer[i]));
    }
    
    // Only emit if values actually changed
    if (newValues != m_values) {
        m_values = newValues;
        emit valuesChanged();
    }
}

void CavaProvider::initCava() {
    if (m_plan || m_bars <= 0) return;
    
    // Initialize cava plan
    // Parameters: bars, sample_rate, input_channels, mono_opt, noise_reduction, lower_cutoff, upper_cutoff
    m_plan = cava_init(m_bars, ac::SAMPLE_RATE, 1, 1, m_noiseReduction, 20, 20000);
    
    if (!m_plan || m_plan->status == -1) {
        qWarning() << "CavaProvider: Failed to initialize cava plan";
        cleanupCava();
        return;
    }
    
    // Allocate output buffer
    m_output_buffer = new double[m_bars];
    std::fill(m_output_buffer, m_output_buffer + m_bars, 0.0);
    
    m_initialized = true;
    qDebug() << "CavaProvider: Initialized with" << m_bars << "bars";
}

void CavaProvider::cleanupCava() {
    if (m_plan) {
        cava_destroy(m_plan);
        m_plan = nullptr;
    }
    
    if (m_output_buffer) {
        delete[] m_output_buffer;
        m_output_buffer = nullptr;
    }
    
    m_initialized = false;
}

void CavaProvider::applyMonstercatFilter(double* data, int n) {
    if (n <= 0) return;
    static thread_local std::vector<double> src;
    src.assign(data, data+n);        // no re-alloc if capacity large enough

    const double inv = 1.0 / 1.5;
    double carry = 0.0;
    for (int i=0; i<n; ++i) { carry = std::max(src[i], carry*inv); data[i] = carry; }
    carry = 0.0;
    for (int i=n-1; i>=0; --i) { carry = std::max(src[i], carry*inv); data[i] = std::max(data[i], carry); }
}

} // namespace cava_plugin