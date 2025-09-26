#include "audiocollector.h"
#include <QDebug>
#include <QThread>
#include <pipewire/pipewire.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/props.h>
#include <spa/param/latency-utils.h>
#include <spa/param/buffers.h>
#include <cstring>

namespace cava_plugin {

// PipeWire callbacks
static void on_stream_param_changed(void *data, uint32_t id, const struct spa_pod *param);
static void on_stream_process(void *data);

static const struct pw_stream_events stream_events = {
    .version = PW_VERSION_STREAM_EVENTS,
    .param_changed = on_stream_param_changed,
    .process = on_stream_process,
};

AudioCollector::AudioCollector(AudioSource source, QObject* parent)
    : QObject(parent), m_audioSource(source) {
    pw_init(nullptr, nullptr);
}

AudioCollector::~AudioCollector() {
    stop();
    cleanupPipeWire();
    pw_deinit();
}

void AudioCollector::start() {
    if (m_running) return;
    
    qDebug() << "AudioCollector: Starting audio capture";
    
    m_running = true;
    initPipeWire();
}

void AudioCollector::stop() {
    if (!m_running) return;
    
    qDebug() << "AudioCollector: Stopping audio capture";
    
    m_running = false;
    cleanupPipeWire();
}

void AudioCollector::setAudioSource(AudioSource source) {
    if (m_audioSource == source) return;
    
    m_audioSource = source;
    
    // Restart PipeWire with new source if running
    if (m_running) {
        cleanupPipeWire();
        initPipeWire();
    }
}

void AudioCollector::initPipeWire() {
    m_loop = pw_main_loop_new(nullptr);
    if (!m_loop) {
        qWarning() << "AudioCollector: Failed to create PipeWire main loop";
        return;
    }
    
    struct pw_context* context = pw_context_new(pw_main_loop_get_loop(m_loop), nullptr, 0);
    if (!context) {
        qWarning() << "AudioCollector: Failed to create PipeWire context";
        return;
    }
    
    struct pw_core* core = pw_context_connect(context, nullptr, 0);
    if (!core) {
        qWarning() << "AudioCollector: Failed to connect to PipeWire";
        return;
    }
    
    // Create audio stream name and properties based on audio source
    const char* streamName;
    struct pw_properties* props;
    
    if (m_audioSource == static_cast<AudioSource>(0)) { // SystemAudio
        streamName = "cava-plugin-system-audio";
        props = pw_properties_new(
            PW_KEY_MEDIA_TYPE, "Audio",
            PW_KEY_MEDIA_CATEGORY, "Capture",
            PW_KEY_MEDIA_ROLE, "Music", 
            PW_KEY_TARGET_OBJECT, "@DEFAULT_SINK@",  // Target default sink for monitor
            PW_KEY_STREAM_CAPTURE_SINK, "true",      // Capture sink output (monitor)
            nullptr);
    } else { // Microphone
        streamName = "cava-plugin-microphone";
        props = pw_properties_new(
            PW_KEY_MEDIA_TYPE, "Audio",
            PW_KEY_MEDIA_CATEGORY, "Capture",
            PW_KEY_MEDIA_ROLE, "Communication",
            PW_KEY_TARGET_OBJECT, "@DEFAULT_SOURCE@", // Target default source (microphone)
            nullptr);
    }
    
    m_stream = pw_stream_new_simple(
        pw_main_loop_get_loop(m_loop),
        streamName,
        props,
        &stream_events,
        this);
    
    if (!m_stream) {
        qWarning() << "AudioCollector: Failed to create PipeWire stream";
        return;
    }
    
    // Set up audio format
    uint8_t buffer[1024];
    struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
    
    struct spa_audio_info_raw audio_info = {};
    audio_info.format = SPA_AUDIO_FORMAT_F32_LE;
    audio_info.channels = 1;
    audio_info.rate = ac::SAMPLE_RATE;
    
    const struct spa_pod* params[1] = {
        spa_format_audio_raw_build(&b, SPA_PARAM_EnumFormat, &audio_info)
    };
    
    // Connect stream with autoconnect to the targeted sink monitor
    if (pw_stream_connect(m_stream,
                         PW_DIRECTION_INPUT,
                         PW_ID_ANY,
                         static_cast<pw_stream_flags>(
                             PW_STREAM_FLAG_AUTOCONNECT |
                             PW_STREAM_FLAG_MAP_BUFFERS),
                         params, 1) < 0) {
        qWarning() << "AudioCollector: Failed to connect PipeWire stream to speaker monitor";
        return;
    }
    
    // Run PipeWire loop in separate thread
    m_thread = std::make_unique<QThread>();
    QObject::connect(m_thread.get(), &QThread::started, [this]() {
        pw_main_loop_run(m_loop);
    });
    m_thread->start();
}

void AudioCollector::cleanupPipeWire() {
    if (m_thread && m_thread->isRunning()) {
        pw_main_loop_quit(m_loop);
        m_thread->quit();
        m_thread->wait();
    }
    
    if (m_stream) {
        pw_stream_destroy(m_stream);
        m_stream = nullptr;
    }
    
    if (m_loop) {
        pw_main_loop_destroy(m_loop);
        m_loop = nullptr;
    }
}

size_t AudioCollector::readChunk(float* buffer) {
    // If we have too much data buffered (more than ~50ms), skip ahead to reduce latency
    size_t available = m_ring.available();
    const size_t max_latency_samples = ac::SAMPLE_RATE / 20; // 50ms worth of samples
    
    if (available > max_latency_samples) {
        // Skip ahead by discarding old data, keeping only the most recent ~25ms
        size_t skip_amount = available - (ac::SAMPLE_RATE / 40);
        float discard_buffer[1024];
        while (skip_amount > 0) {
            size_t to_skip = std::min(skip_amount, sizeof(discard_buffer) / sizeof(float));
            size_t skipped = m_ring.read(discard_buffer, to_skip);
            m_data_counter.fetch_sub(skipped, std::memory_order_relaxed);
            skip_amount -= skipped;
        }
    }
    
    size_t got = m_ring.read(buffer, ac::CHUNK_SIZE);
    
    // Update counter to reflect consumed data
    if (got > 0) {
        m_data_counter.fetch_sub(got, std::memory_order_relaxed);
    }
    
    // Zero-fill remaining if underfilled
    if (got < ac::CHUNK_SIZE) {
        std::memset(buffer + got, 0, (ac::CHUNK_SIZE - got) * sizeof(float));
    }
    
    return ac::CHUNK_SIZE;
}

void AudioCollector::writeAudioData(const float* data, size_t frames) {
    size_t written = m_ring.write(data, frames);
    
    // Update counter and check if we have enough data for processing
    size_t new_count = m_data_counter.fetch_add(written, std::memory_order_relaxed) + written;
    
    // Emit signal when we have at least CHUNK_SIZE samples available
    // Use a simple threshold to avoid too frequent signaling
    if ((new_count / ac::CHUNK_SIZE) > ((new_count - written) / ac::CHUNK_SIZE)) {
        emit dataAvailable();
    }
}

// PipeWire callback implementations
static void on_stream_param_changed(void *data, uint32_t id, const struct spa_pod *param) {
    Q_UNUSED(data)
    Q_UNUSED(id) 
    Q_UNUSED(param)
    // Handle parameter changes if needed
}

static void on_stream_process(void *data) {
    AudioCollector* collector = static_cast<AudioCollector*>(data);
    
    struct pw_buffer* pw_buf = pw_stream_dequeue_buffer(collector->getStream());
    if (!pw_buf) return;
    
    struct spa_buffer* buf = pw_buf->buffer;
    if (!buf->datas[0].data) {
        pw_stream_queue_buffer(collector->getStream(), pw_buf);
        return;
    }
    
    const float* audio_data = static_cast<const float*>(buf->datas[0].data);
    const size_t frames = buf->datas[0].chunk->size / sizeof(float);
    
    collector->writeAudioData(audio_data, frames);
    
    pw_stream_queue_buffer(collector->getStream(), pw_buf);
}

} // namespace cava_plugin