#include "audiocollector.h"
#include <QDebug>
#include <QThread>
#include <pipewire/pipewire.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/props.h>
#include <spa/param/latency-utils.h>
#include <spa/param/buffers.h>
#include <cstring>
#include <vector>

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

    // ---- Stream props ----
    const char* streamName = (m_audioSource == static_cast<AudioSource>(0))
        ? "cava-plugin-system-audio"
        : "cava-plugin-microphone";

    pw_properties* props = pw_properties_new(
        PW_KEY_MEDIA_TYPE, "Audio",
        PW_KEY_MEDIA_CATEGORY, "Capture",
        PW_KEY_NODE_LATENCY, "128/48000",   // tighten quantum; try "64/48000" if stable
        PW_KEY_NODE_RATE,    "48000/1",
        nullptr
    );
    if (m_audioSource == static_cast<AudioSource>(0)) {
        pw_properties_set(props, PW_KEY_MEDIA_ROLE, "Music");
        pw_properties_set(props, PW_KEY_TARGET_OBJECT, "@DEFAULT_SINK@");
        pw_properties_set(props, PW_KEY_STREAM_CAPTURE_SINK, "true");
    } else {
        pw_properties_set(props, PW_KEY_MEDIA_ROLE, "Communication");
        pw_properties_set(props, PW_KEY_TARGET_OBJECT, "@DEFAULT_SOURCE@");
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

    // ---- Params: format + small buffers + latency hint ----
    uint8_t paramBuf[1024];
    spa_pod_builder b = SPA_POD_BUILDER_INIT(paramBuf, sizeof(paramBuf));

    spa_audio_info_raw ai{};
    ai.format   = SPA_AUDIO_FORMAT_F32_LE;
    ai.channels = 1;
    ai.rate     = ac::SAMPLE_RATE;

    const uint32_t bytesPerFrame = sizeof(float); // mono f32
    const uint32_t minFrames     = 64;
    const uint32_t defFrames     = 128;
    const uint32_t maxFrames     = 1024;

    const struct spa_pod* params[3];
    uint32_t n_params = 0;

    // 1) format
    params[n_params++] = spa_format_audio_raw_build(&b, SPA_PARAM_EnumFormat, &ai);

    // 2) buffers (cast the macro's void* to const spa_pod*)
    params[n_params++] = static_cast<const struct spa_pod*>(
        spa_pod_builder_add_object(
            &b, SPA_TYPE_OBJECT_ParamBuffers, SPA_PARAM_Buffers,
            SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(3, 2, 8),
            SPA_PARAM_BUFFERS_blocks,  SPA_POD_Int(1),
            SPA_PARAM_BUFFERS_size,    SPA_POD_CHOICE_RANGE_Int(defFrames * bytesPerFrame,
                                                                 minFrames * bytesPerFrame,
                                                                 maxFrames * bytesPerFrame),
            SPA_PARAM_BUFFERS_stride,  SPA_POD_Int(bytesPerFrame)
        )
    );

    // 3) latency hint (input); spa_latency_build already returns const spa_pod*
    spa_latency_info lat = SPA_LATENCY_INFO(
        SPA_DIRECTION_INPUT,
        .min_quantum = 2,
        .max_quantum = 4
    );
    params[n_params++] = spa_latency_build(&b, SPA_PARAM_Latency, &lat);

    const pw_stream_flags flags =
        (pw_stream_flags)(
            PW_STREAM_FLAG_AUTOCONNECT |
            PW_STREAM_FLAG_MAP_BUFFERS |
            PW_STREAM_FLAG_RT_PROCESS
        );

    if (pw_stream_connect(m_stream,
                          PW_DIRECTION_INPUT,
                          PW_ID_ANY,
                          flags,
                          params, n_params) < 0) {
        qWarning() << "AudioCollector: Failed to connect PipeWire stream";
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
    if ((new_count / ac::CHUNK_SIZE) > ((new_count - written) / ac::CHUNK_SIZE)) {
        emit dataAvailable();
    }
}

// PipeWire callback implementations
static void on_stream_param_changed(void *data, uint32_t id, const struct spa_pod *param) {
    Q_UNUSED(id);
    if (!param) return;

    // Optional: log negotiated latency
    spa_latency_info info{};
    if (spa_latency_parse(param, &info) == 0) {
        qDebug() << "PipeWire latency changed:"
                 << (info.direction == SPA_DIRECTION_INPUT ? "input" : "output")
                 << "min-quantum=" << info.min_quantum
                 << "max-quantum=" << info.max_quantum;
    }
}

static void on_stream_process(void *data) {
    auto* collector = static_cast<AudioCollector*>(data);

    pw_buffer* pwb = pw_stream_dequeue_buffer(collector->getStream());
    if (!pwb) return;

    spa_buffer* b = pwb->buffer;
    if (!b || b->n_datas == 0) {
        pw_stream_queue_buffer(collector->getStream(), pwb);
        return;
    }

    spa_data& d = b->datas[0];
    if (!d.data || !d.chunk) {
        pw_stream_queue_buffer(collector->getStream(), pwb);
        return;
    }

    const uint32_t offs   = d.chunk->offset;
    const uint32_t nbytes = d.chunk->size;
    const uint32_t stride = d.chunk->stride ? d.chunk->stride : static_cast<uint32_t>(sizeof(float)); // bytes per frame (mono f32 = 4)

    if (nbytes >= stride) {
        const uint8_t* base = static_cast<const uint8_t*>(d.data) + offs;
        const size_t frames = nbytes / stride;

        if (stride == sizeof(float)) {
            const float* samples = reinterpret_cast<const float*>(base);
            collector->writeAudioData(samples, frames);
        } else {
            std::vector<float> tmp(frames);
            for (size_t i = 0; i < frames; ++i) {
                tmp[i] = *reinterpret_cast<const float*>(base + i * stride);
            }
            collector->writeAudioData(tmp.data(), frames);
        }
    }

    pw_stream_queue_buffer(collector->getStream(), pwb);
}

} // namespace cava_plugin
