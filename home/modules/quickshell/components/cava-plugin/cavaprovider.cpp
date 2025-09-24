#include "cavaprovider.h"
#include "audiocollector.h"
#include <QDebug>
#include <QTimer>
#include <cava/cavacore.h>
#include <cmath>
#include <algorithm>

namespace cava_plugin {

CavaProvider::CavaProvider(QObject* parent)
    : CavaProvider(AudioSource::SystemAudio, parent) {}

CavaProvider::CavaProvider(AudioSource source, QObject* parent)
    : QObject(parent)
    , m_timer(new QTimer(this))
    , m_audioSource(source)
{
    m_values.resize(m_bars, 0.0);
    m_input_buffer = new double[ac::CHUNK_SIZE];
    
    // Create audio collector for specified source
    m_audioCollector = new AudioCollector(source, this);
    
    // Set up processing timer (60 FPS)
    m_timer->setInterval(16);
    connect(m_timer, &QTimer::timeout, this, &CavaProvider::processAudio);
    
    initCava();
    
    // Start audio collection and processing
    m_audioCollector->start();
    m_timer->start();
}

CavaProvider::~CavaProvider() {
    m_timer->stop();
    if (m_audioCollector) {
        m_audioCollector->stop();
    }
    cleanupCava();
    delete[] m_input_buffer;
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



void CavaProvider::processAudio() {
    if (!m_audioCollector || !m_plan || !m_initialized) return;
    
    // Read audio data from collector
    const size_t samples_read = m_audioCollector->readChunk(m_input_buffer);
    
    if (samples_read == 0) return;
    
    // Process audio through cava
    cava_execute(m_input_buffer, static_cast<int>(samples_read), m_output_buffer, m_plan);
    
    // Apply monstercat smoothing filter (from caelestia) - disabled to avoid skewing data
    // applyMonstercatFilter(m_output_buffer, m_bars);
    
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
    m_plan = cava_init(m_bars, ac::SAMPLE_RATE, 1, 1, 0.3, 50, 10000);
    
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

void CavaProvider::applyMonstercatFilter(double* data, int size) {
    // Apply monstercat smoothing filter (spreads peaks to neighboring bars)
    for (int i = 0; i < size; i++) {
        // Spread to the left
        for (int j = i - 1; j >= 0; j--) {
            data[j] = std::max(data[i] / std::pow(1.5, i - j), data[j]);
        }
        // Spread to the right  
        for (int j = i + 1; j < size; j++) {
            data[j] = std::max(data[i] / std::pow(1.5, j - i), data[j]);
        }
    }
}

} // namespace cava_plugin