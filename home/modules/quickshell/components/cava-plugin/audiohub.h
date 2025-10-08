#pragma once

#include <QObject>

namespace cava_plugin {

class CavaProvider;

class AudioHub : public QObject {
    Q_OBJECT

public:
    static AudioHub* instance();

    CavaProvider* systemProvider() const { return m_systemProvider; }
    CavaProvider* microphoneProvider() const { return m_microphoneProvider; }

    int maxBars() const { return m_maxBars; }
    void setMaxBars(int bars);

    bool monstercatFilter() const { return m_monstercatFilter; }
    void setMonstercatFilter(bool enabled);

private:
    AudioHub();
    ~AudioHub() override = default;
    Q_DISABLE_COPY_MOVE(AudioHub)

    CavaProvider* m_systemProvider = nullptr;
    CavaProvider* m_microphoneProvider = nullptr;
    int m_maxBars = 40;
    bool m_monstercatFilter = true;
};

} // namespace cava_plugin
