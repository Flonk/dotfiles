#include "spectrumanalyzer.h"

#include <algorithm>
#include <cmath>
#include <numbers>
#include <new>
#include <stdexcept>

namespace quickmilk {
namespace {
constexpr double kEpsilon = 1e-9;
constexpr double kEaseTransitionStart = 0.85;
constexpr double kEaseMinRange = 1e-6;
constexpr double kBaseEasePower = 3.0;
constexpr double kMinEasePower = 2.2;
constexpr double kMaxEasePower = 8.0;
constexpr double kDynamicRangeTarget = 0.35;
constexpr double kDynamicRangeScale = 8.0;

double applyInOutEase(double normalized, double power) {
    const double x = std::clamp(normalized, 0.0, 1.0);
    if (x <= kEaseTransitionStart) {
        return std::pow(x, power);
    }

    const double transitionRange = std::max(1.0 - kEaseTransitionStart, kEaseMinRange);
    const double t = std::clamp((x - kEaseTransitionStart) / transitionRange, 0.0, 1.0);
    const double baseAtTransition = std::pow(kEaseTransitionStart, power);
    const double easeOut = 1.0 - std::pow(1.0 - t, power);
    return baseAtTransition + (1.0 - baseAtTransition) * easeOut;
}
}

SpectrumAnalyzer::SpectrumAnalyzer(int bars, double sampleRate, std::size_t frameSize, std::size_t hopSize)
    : m_bars(std::max(1, bars))
    , m_sampleRate(sampleRate)
    , m_frameSize(frameSize)
    , m_hopSize(hopSize)
    , m_fifo()
    , m_window(frameSize)
    , m_magnitudes(frameSize / 2 + 1)
    , m_binWeights(frameSize / 2 + 1, 1.0)
{
    m_fifo.reserve(frameSize * 2);

    m_fftInput = static_cast<double*>(fftw_malloc(sizeof(double) * m_frameSize));
    m_fftOutput = static_cast<fftw_complex*>(fftw_malloc(sizeof(fftw_complex) * (m_frameSize / 2 + 1)));

    if (!m_fftInput || !m_fftOutput) {
        throw std::bad_alloc();
    }

    m_plan = fftw_plan_dft_r2c_1d(static_cast<int>(m_frameSize), m_fftInput, m_fftOutput, FFTW_MEASURE);
    if (!m_plan) {
        throw std::runtime_error("Failed to create FFTW plan");
    }

    rebuildWindow();
    rebuildBinMapping();
}

SpectrumAnalyzer::~SpectrumAnalyzer() {
    if (m_plan) {
        fftw_destroy_plan(m_plan);
    }
    if (m_fftInput) {
        fftw_free(m_fftInput);
    }
    if (m_fftOutput) {
        fftw_free(m_fftOutput);
    }
}

void SpectrumAnalyzer::setBarCount(int bars) {
    int newBars = std::max(1, bars);
    if (newBars == m_bars) {
        return;
    }
    m_bars = newBars;
    rebuildBinMapping();
}

void SpectrumAnalyzer::setSampleRate(double sampleRate) {
    if (std::abs(sampleRate - m_sampleRate) < 1e-3) {
        return;
    }
    m_sampleRate = sampleRate;
    rebuildBinMapping();
}

void SpectrumAnalyzer::setFrequencyRange(double minFrequency, double maxFrequency) {
    minFrequency = std::clamp(minFrequency, 1.0, maxFrequency);
    maxFrequency = std::max(minFrequency, maxFrequency);

    if (std::abs(minFrequency - m_minFrequency) < 1e-6 && std::abs(maxFrequency - m_maxFrequency) < 1e-6) {
        return;
    }

    m_minFrequency = minFrequency;
    m_maxFrequency = maxFrequency;
    rebuildBinMapping();
}

void SpectrumAnalyzer::setDynamicFalloff(double falloff) {
    falloff = std::clamp(falloff, 0.0, 0.9999);
    if (std::abs(falloff - m_dynamicFalloff) < 1e-6) {
        return;
    }

    m_dynamicFalloff = falloff;
}

void SpectrumAnalyzer::setDynamicRise(double rise) {
    rise = std::clamp(rise, 0.0, 1.0);
    if (std::abs(rise - m_dynamicRise) < 1e-6) {
        return;
    }

    m_dynamicRise = rise;
}

void SpectrumAnalyzer::setAutoGainFloor(double floor) {
    floor = std::clamp(floor, kEpsilon, 10.0);
    if (std::abs(floor - m_autoGainFloor) < 1e-6) {
        return;
    }

    m_autoGainFloor = floor;
    m_dynamicMax = std::max(m_dynamicMax, m_autoGainFloor);
}

bool SpectrumAnalyzer::consume(const float* samples, std::size_t count, QVector<double>& outBars) {
    if (!samples || count == 0) {
        return false;
    }

    m_fifo.insert(m_fifo.end(), samples, samples + count);

    bool updated = false;
    while (m_fifo.size() >= m_frameSize) {
        if (processFrame(outBars)) {
            updated = true;
        }

        if (m_fifo.size() > m_hopSize) {
            m_fifo.erase(m_fifo.begin(), m_fifo.begin() + static_cast<long>(m_hopSize));
        } else {
            m_fifo.clear();
        }
    }

    return updated;
}

void SpectrumAnalyzer::rebuildWindow() {
    constexpr double pi = std::numbers::pi;
    for (std::size_t i = 0; i < m_frameSize; ++i) {
        double x = static_cast<double>(i) / static_cast<double>(m_frameSize - 1);
        m_window[i] = 0.5 - 0.5 * std::cos(2.0 * pi * x); // Hann window
    }
}

void SpectrumAnalyzer::rebuildBinMapping() {
    const std::size_t binCount = m_frameSize / 2 + 1;
    m_binStart.resize(m_bars);
    m_binEnd.resize(m_bars);
    m_binWeights.resize(binCount);

    const double nyquist = m_sampleRate / 2.0;
    const double lower = std::clamp(m_minFrequency, 1.0, nyquist);
    const double upper = std::clamp(m_maxFrequency, lower, nyquist);
    const double ratio = std::max(1.0, upper / lower);

    const double logRange = (ratio > 1.0) ? std::log(ratio) : 1.0;

    for (std::size_t bin = 0; bin < binCount; ++bin) {
        if (bin == 0) {
            m_binWeights[bin] = 0.0;
            continue;
        }

        const double frequency = (static_cast<double>(bin) * m_sampleRate) / static_cast<double>(m_frameSize);
        const double clamped = std::clamp(frequency, lower, upper);

        double normalized = 0.0;
        if (ratio > 1.0) {
            normalized = std::log(clamped / lower) / logRange;
        }
        normalized = std::clamp(normalized, 0.0, 1.0);

        // Compensate for the typical 1/f spectrum by boosting higher frequencies.
        const double freqRatio = std::max(clamped / lower, 1.0);
        const double boosted = std::pow(freqRatio, 0.40); // stronger compensation for treble falloff
        const double tilt = 0.1 + 0.9 * normalized;
        m_binWeights[bin] = std::clamp(boosted * tilt, 0.3, 12.0);
    }

    for (int i = 0; i < m_bars; ++i) {
        const double startFrac = static_cast<double>(i) / m_bars;
        const double endFrac = static_cast<double>(i + 1) / m_bars;

        const double fStart = lower * std::pow(ratio, startFrac);
        const double fEnd = lower * std::pow(ratio, endFrac);

        std::size_t binStart = static_cast<std::size_t>(std::floor(fStart * m_frameSize / m_sampleRate));
        std::size_t binEnd = static_cast<std::size_t>(std::ceil(fEnd * m_frameSize / m_sampleRate));

        binStart = std::clamp<std::size_t>(binStart, 0, binCount - 1);
        binEnd = std::clamp<std::size_t>(binEnd, binStart + 1, binCount);

        m_binStart[i] = binStart;
        m_binEnd[i] = binEnd;
    }
}

bool SpectrumAnalyzer::processFrame(QVector<double>& outBars) {
    if (!m_plan || m_fifo.size() < m_frameSize) {
        return false;
    }

    for (std::size_t i = 0; i < m_frameSize; ++i) {
        m_fftInput[i] = static_cast<double>(m_fifo[i]) * m_window[i];
    }

    fftw_execute(m_plan);

    const std::size_t binCount = m_frameSize / 2 + 1;
    for (std::size_t i = 0; i < binCount; ++i) {
        const double real = m_fftOutput[i][0];
        const double imag = m_fftOutput[i][1];
        const double magnitude = std::sqrt(real * real + imag * imag) + kEpsilon;
        m_magnitudes[i] = magnitude * m_binWeights[i];
    }

    if (outBars.size() != m_bars) {
        outBars.resize(m_bars);
    }

    double peak = kEpsilon;
    for (int bar = 0; bar < m_bars; ++bar) {
        const std::size_t start = m_binStart[bar];
        const std::size_t end = m_binEnd[bar];

        double value = 0.0;
        for (std::size_t bin = start; bin < end; ++bin) {
            value = std::max(value, m_magnitudes[bin]);
        }

        outBars[bar] = value;
        peak = std::max(peak, value);
    }

    if (peak > kEpsilon) {
        const double invPeak = 1.0 / peak;
        QVector<double> normalized(outBars.size());
        double sumNormalized = 0.0;
        int activeCount = 0;

        for (int i = 0; i < outBars.size(); ++i) {
            const double n = std::clamp(outBars[i] * invPeak, 0.0, 1.0);
            normalized[i] = n;
            if (n > 0.0) {
                sumNormalized += n;
                ++activeCount;
            }
        }

        const double meanNormalized = activeCount > 0 ? (sumNormalized / static_cast<double>(activeCount)) : 0.0;
        const double dynamicRange = std::clamp(1.0 - meanNormalized, 0.0, 1.0);
        const double powerAdjustment = (kDynamicRangeTarget - dynamicRange) * kDynamicRangeScale;
        const double easePower = std::clamp(kBaseEasePower + powerAdjustment, kMinEasePower, kMaxEasePower);

        for (int i = 0; i < outBars.size(); ++i) {
            outBars[i] = applyInOutEase(normalized[i], easePower) * peak;
        }
    }

    peak = std::max(peak, m_autoGainFloor);

    if (peak > m_dynamicMax) {
        m_dynamicMax += (peak - m_dynamicMax) * m_dynamicRise;
    } else {
        m_dynamicMax = m_dynamicMax * m_dynamicFalloff + peak * (1.0 - m_dynamicFalloff);
    }
    m_dynamicMax = std::max(std::max(m_dynamicMax, kEpsilon), m_autoGainFloor);

    const double inv = 1.0 / m_dynamicMax;
    for (double& v : outBars) {
        v = std::clamp(v * inv, 0.0, 1.0);
    }

    return true;
}

} // namespace quickmilk
