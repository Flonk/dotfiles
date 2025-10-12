#pragma once

#include <QVector>
#include <vector>

namespace quickmilk {

class VisualizerEffects {
public:
    VisualizerEffects() = default;

    void reset(int bars);

    void setSmoothingAlpha(double alpha) { m_smoothingAlpha = alpha; }
    double smoothingAlpha() const { return m_smoothingAlpha; }

    void setGravityDecay(double decay) { m_gravityDecay = decay; }
    double gravityDecay() const { return m_gravityDecay; }

    void setNoiseFloorDecayRange(double minDecay, double maxDecay);
    double noiseFloorMinDecay() const { return m_noiseFloorMinDecay; }
    double noiseFloorMaxDecay() const { return m_noiseFloorMaxDecay; }

    void setNoiseFloorRiseRange(double minRise, double maxRise);
    double noiseFloorMinRise() const { return m_noiseFloorMinRise; }
    double noiseFloorMaxRise() const { return m_noiseFloorMaxRise; }

    void setNoiseFloorClamp(double clamp) { m_noiseFloorClamp = clamp; }
    double noiseFloorClamp() const { return m_noiseFloorClamp; }

    void process(QVector<double>& values, double noiseReduction, bool enableMonstercat);

private:
    void ensureBuffers(int size);
    void applyNoiseReduction(QVector<double>& values, double intensity);
    void applyMonstercatFilter(QVector<double>& values);
    void applyTemporalEffects(QVector<double>& values);

    std::vector<double> m_noiseFloor;
    std::vector<double> m_smoothedBars;
    std::vector<double> m_peakBars;

    double m_smoothingAlpha = 0.35;
    double m_gravityDecay = 0.85;

    double m_noiseFloorMinDecay = 0.90;
    double m_noiseFloorMaxDecay = 0.9995;
    double m_noiseFloorMinRise = 0.002;
    double m_noiseFloorMaxRise = 0.05;
    double m_noiseFloorClamp = 1e-4;
};

} // namespace quickmilk
