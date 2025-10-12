#pragma once

#include <qqmlintegration.h>

namespace cava_plugin {
Q_NAMESPACE

enum class AudioSource {
    SystemAudio = 0,  // System output (speakers/headphones) 
    Microphone = 1    // Microphone input
};
Q_ENUM_NS(AudioSource)

} // namespace cava_plugin