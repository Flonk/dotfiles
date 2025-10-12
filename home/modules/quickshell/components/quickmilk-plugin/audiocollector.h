#pragma once

#include <QObject>
#include <QThread>
#include <atomic>
#include <vector>
#include <memory>
#include <qqmlintegration.h>
#include "spsc_ring.h"

// Forward declarations
struct pw_main_loop;
struct pw_stream;

namespace quickmilk {
Q_NAMESPACE

enum class AudioSource {
    SystemAudio = 0,  // System output (speakers/headphones) 
    Microphone = 1    // Microphone input
};
Q_ENUM_NS(AudioSource)

namespace ac {
    constexpr quint32 SAMPLE_RATE = 48000;
    constexpr quint32 CHUNK_SIZE = 512;
}

class AudioCollector : public QObject {
    Q_OBJECT

public:
    explicit AudioCollector(AudioSource source = AudioSource::SystemAudio, QObject* parent = nullptr);
    ~AudioCollector();
    
    void start();
    void stop();
    
    void setAudioSource(AudioSource source);
    AudioSource audioSource() const { return m_audioSource; }
    
    // Read audio chunk data (returns number of samples read)
    size_t readChunk(float* buffer);
    
    // Audio data handling (public for PipeWire callbacks)
    void writeAudioData(const float* data, size_t frames);
    
    // Stream access for callbacks
    ::pw_stream* getStream() { return m_stream; }

signals:
    void dataAvailable(); // Emitted when enough data is available for processing

private:
    
    // PipeWire integration
    void initPipeWire();
    void cleanupPipeWire();
    
    SpscRing m_ring{1 << 12}; // 4K samples ring buffer (~93ms at 44.1kHz)
    std::atomic<size_t> m_data_counter{0}; // Track total data written for signaling
    std::atomic<bool> m_running{false};
    AudioSource m_audioSource = static_cast<AudioSource>(0); // SystemAudio
    
    // PipeWire objects
    ::pw_main_loop* m_loop = nullptr;
    ::pw_stream* m_stream = nullptr;
    std::unique_ptr<QThread> m_thread;
    
    friend class PipeWireWorker;
};

} // namespace quickmilk