#include "visualizereffects.h"

#include <algorithm>
#include <cmath>
#include <vector>

namespace quickmilk {

void VisualizerEffects::reset(int bars) {
    m_noiseFloor.assign(bars, 0.0);
    m_smoothedBars.assign(bars, 0.0);
    m_peakBars.assign(bars, 0.0);
}

void VisualizerEffects::setNoiseFloorDecayRange(double minDecay, double maxDecay) {
    m_noiseFloorMinDecay = std::clamp(minDecay, 0.0, 1.0);
    m_noiseFloorMaxDecay = std::clamp(maxDecay, m_noiseFloorMinDecay, 1.0);
}

void VisualizerEffects::setNoiseFloorRiseRange(double minRise, double maxRise) {
    m_noiseFloorMinRise = std::max(0.0, minRise);
    m_noiseFloorMaxRise = std::max(m_noiseFloorMinRise, maxRise);
}

void VisualizerEffects::process(QVector<double>& values, double noiseReduction, bool enableMonstercat) {
    if (values.isEmpty()) {
        return;
    }

    ensureBuffers(values.size());

    applyNoiseReduction(values, noiseReduction);

    if (enableMonstercat) {
        applyMonstercatFilter(values);
    }

    applyTemporalEffects(values);
}

void VisualizerEffects::ensureBuffers(int size) {
    if (static_cast<int>(m_noiseFloor.size()) != size) {
        reset(size);
    }
}

void VisualizerEffects::applyNoiseReduction(QVector<double>& values, double intensity) {
    intensity = std::clamp(intensity, 0.0, 1.0);
    if (intensity <= 0.0) {
        return;
    }

    const double decay = std::lerp(m_noiseFloorMinDecay, m_noiseFloorMaxDecay, intensity);
    const double rise = std::lerp(m_noiseFloorMaxRise, m_noiseFloorMinRise, intensity);

    for (int i = 0; i < values.size(); ++i) {
        double sample = std::clamp(values[i], 0.0, 1.0);
        double floor = m_noiseFloor[i];

        floor *= decay;
        if (sample < floor) {
            floor = sample;
        } else {
            floor += (sample - floor) * rise;
        }

        if (floor < m_noiseFloorClamp) {
            floor = 0.0;
        }

        m_noiseFloor[i] = floor;

        double cleaned = sample - floor * intensity;
        values[i] = std::clamp(cleaned, 0.0, 1.0);
    }
}

void VisualizerEffects::applyMonstercatFilter(QVector<double>& values) {
    if (values.isEmpty()) {
        return;
    }

    static thread_local std::vector<double> scratch;
    scratch.assign(values.begin(), values.end());

    const double inv = 1.0 / 1.5;
    double carry = 0.0;
    for (int i = 0; i < values.size(); ++i) {
        carry = std::max(scratch[i], carry * inv);
        values[i] = carry;
    }

    carry = 0.0;
    for (int i = values.size() - 1; i >= 0; --i) {
        carry = std::max(scratch[i], carry * inv);
        values[i] = std::max(values[i], carry);
    }
}

void VisualizerEffects::applyTemporalEffects(QVector<double>& values) {
    constexpr double kMinValue = 1e-4;

    for (int i = 0; i < values.size(); ++i) {
        double current = std::clamp(values[i], 0.0, 1.0);

        double smoothed = m_smoothingAlpha * current + (1.0 - m_smoothingAlpha) * m_smoothedBars[i];
        if (smoothed < kMinValue) {
            smoothed = 0.0;
        }

        double peak = m_peakBars[i];
        if (smoothed >= peak) {
            peak = smoothed;
        } else {
            peak *= m_gravityDecay;
            if (peak < smoothed) {
                peak = smoothed;
            }
        }

        m_smoothedBars[i] = smoothed;
        m_peakBars[i] = peak;
        values[i] = peak;
    }
}

} // namespace quickmilk
