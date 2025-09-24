#pragma once

#include "cavaprovider.h"
#include <qqmlintegration.h>
#include <QDebug>

namespace cava_plugin {

class MicrophoneCavaProvider : public CavaProvider {
    Q_OBJECT
    QML_ELEMENT
    
public:
    explicit MicrophoneCavaProvider(QObject* parent = nullptr) 
        : CavaProvider(AudioSource::Microphone, parent) {
        qDebug() << "MicrophoneCavaProvider: Initialized for microphone audio";
    }
};

} // namespace cava_plugin