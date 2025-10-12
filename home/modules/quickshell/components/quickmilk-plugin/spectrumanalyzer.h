#pragma once

#include <QVector>
#include <cstddef>
#include <vector>
#include <fftw3.h>

namespace quickmilk {

class SpectrumAnalyzer {
public:
    SpectrumAnalyzer(int bars, double sampleRate, std::size_t frameSize = 2048, std::size_t hopSize = 512);
    ~SpectrumAnalyzer();

    SpectrumAnalyzer(const SpectrumAnalyzer&) = delete;
    SpectrumAnalyzer& operator=(const SpectrumAnalyzer&) = delete;

    void setBarCount(int bars);
    int barCount() const { return m_bars; }

    void setSampleRate(double sampleRate);
    double sampleRate() const { return m_sampleRate; }

    void setFrequencyRange(double minFrequency, double maxFrequency);
    double minFrequency() const { return m_minFrequency; }
    double maxFrequency() const { return m_maxFrequency; }

    void setLogScale(double logScale);
    double logScale() const { return m_logScale; }

    void setDynamicFalloff(double falloff);
    double dynamicFalloff() const { return m_dynamicFalloff; }

    void setDynamicRise(double rise);
    double dynamicRise() const { return m_dynamicRise; }

    void setAmplitudeGamma(double gamma);
    double amplitudeGamma() const { return m_amplitudeGamma; }

    void setBandTailMix(double mix);
    double bandTailMix() const { return m_bandTailMix; }

    bool consume(const float* samples, std::size_t count, QVector<double>& outBars);

private:
    void rebuildWindow();
    void rebuildBinMapping();
    bool processFrame(QVector<double>& outBars);

    int m_bars;
    double m_sampleRate;
    double m_minFrequency = 40.0;
    double m_maxFrequency = 20000.0;
    double m_logScale = 1.0;
    double m_dynamicFalloff = 0.99;
    double m_dynamicRise = 0.95;
    double m_amplitudeGamma = 8;
    double m_bandTailMix = 0.2;
    const std::size_t m_frameSize;
    const std::size_t m_hopSize;

    std::vector<float> m_fifo;

    std::vector<double> m_window;
    std::vector<double> m_magnitudes;

    std::vector<std::size_t> m_binStart;
    std::vector<std::size_t> m_binEnd;

    fftw_plan m_plan = nullptr;
    double* m_fftInput = nullptr;
    fftw_complex* m_fftOutput = nullptr;

    double m_dynamicMax = 1.0;
};

} // namespace quickmilk
