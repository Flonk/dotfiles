#include "audiohub.h"

#include "cavaprovider.h"

namespace cava_plugin {

AudioHub::AudioHub()
    : QObject(nullptr)
    , m_systemProvider(new CavaProvider(AudioSource::SystemAudio, this))
    , m_microphoneProvider(new CavaProvider(AudioSource::Microphone, this)) {
    m_systemProvider->setBars(m_maxBars);
    m_microphoneProvider->setBars(m_maxBars);
    m_systemProvider->setEnableMonstercatFilter(m_monstercatFilter);
    m_microphoneProvider->setEnableMonstercatFilter(m_monstercatFilter);
}

AudioHub* AudioHub::instance() {
    static AudioHub hub;
    return &hub;
}

void AudioHub::setMaxBars(int bars) {
    if (bars <= 0) {
        bars = 1;
    }
    if (m_maxBars == bars) {
        return;
    }
    m_maxBars = bars;
    if (m_systemProvider) {
        m_systemProvider->setBars(m_maxBars);
    }
    if (m_microphoneProvider) {
        m_microphoneProvider->setBars(m_maxBars);
    }
}

void AudioHub::setMonstercatFilter(bool enabled) {
    if (m_monstercatFilter == enabled) {
        return;
    }
    m_monstercatFilter = enabled;
    if (m_systemProvider) {
        m_systemProvider->setEnableMonstercatFilter(enabled);
    }
    if (m_microphoneProvider) {
        m_microphoneProvider->setEnableMonstercatFilter(enabled);
    }
}

} // namespace cava_plugin
