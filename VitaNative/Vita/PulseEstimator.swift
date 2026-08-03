import Foundation

struct PulseSample {
    let time: TimeInterval
    let value: Double
}

enum PulseCaptureError: LocalizedError {
    case cameraAccess
    case noStableSignal

    var errorDescription: String? {
        switch self {
        case .cameraAccess:
            return "Camera access is required for a pulse estimate."
        case .noStableSignal:
            return "Vita could not find a stable pulse signal. Keep your finger still and try again."
        }
    }
}

enum PulseEstimator {
    private struct Candidate {
        let bpm: Double
        let correlation: Double
    }

    static func estimate(from samples: [PulseSample]) -> Double? {
        guard samples.count >= 160,
              let first = samples.first,
              let last = samples.last else { return nil }

        let duration = last.time - first.time
        guard duration >= 8 else { return nil }

        let firstCutoff = first.time + 2
        let lastCutoff = last.time - 2
        let windows = [
            samples,
            samples.filter { $0.time >= firstCutoff },
            samples.filter { $0.time <= lastCutoff }
        ]
        let candidates = windows.compactMap(estimateWindow)
        guard candidates.count >= 2 else { return nil }

        let sorted = candidates.map(\.bpm).sorted()
        let median = sorted[sorted.count / 2]
        let stable = candidates.allSatisfy { abs($0.bpm - median) <= 7 }
        guard stable else { return nil }

        return median.rounded()
    }

    private static func estimateWindow(_ samples: [PulseSample]) -> Candidate? {
        guard samples.count >= 100,
              let first = samples.first,
              let last = samples.last else { return nil }

        let duration = last.time - first.time
        guard duration >= 5 else { return nil }
        let sampleRate = Double(samples.count - 1) / duration
        guard (8...60).contains(sampleRate) else { return nil }

        let values = samples.map(\.value)
        let detrended = detrend(values, windowSize: max(8, Int(sampleRate * 1.2)))
        let filtered = smooth(detrended, radius: max(1, Int(sampleRate * 0.04)))
        let signalEnergy = sqrt(filtered.reduce(0) { $0 + ($1 * $1) } / Double(filtered.count))
        guard signalEnergy > 0.00025 else { return nil }

        let minLag = max(2, Int(sampleRate * 60 / 160))
        let maxLag = min(Int(sampleRate * 60 / 45), filtered.count / 2 - 1)
        guard minLag < maxLag else { return nil }

        var correlations = [Double](repeating: -1, count: maxLag + 1)
        for lag in minLag...maxLag {
            correlations[lag] = correlation(at: lag, in: filtered)
        }

        let peakLags = (minLag + 1..<maxLag).filter { lag in
            correlations[lag] >= correlations[lag - 1] && correlations[lag] >= correlations[lag + 1]
        }
        guard let bestLag = peakLags.max(by: { score(for: $0, correlations: correlations) < score(for: $1, correlations: correlations) }) else {
            return nil
        }

        let bestCorrelation = correlations[bestLag]
        guard bestCorrelation >= 0.32 else { return nil }

        let refinedLag = parabolicPeak(at: bestLag, in: correlations)
        let autocorrelationBPM = (60 * sampleRate / refinedLag)
        guard (45...160).contains(autocorrelationBPM),
              let spectrum = spectralCandidate(values: filtered, sampleRate: sampleRate) else { return nil }

        // Autocorrelation can lock onto a slow motion cycle. Require an independent
        // frequency estimate to agree before displaying a camera result.
        var spectralBPM = spectrum.bpm
        if abs((spectralBPM / 2) - autocorrelationBPM) <= 8 {
            spectralBPM /= 2
        } else if abs((spectralBPM * 2) - autocorrelationBPM) <= 8 {
            spectralBPM *= 2
        }
        guard abs(spectralBPM - autocorrelationBPM) <= 8 else { return nil }

        let bpm = (autocorrelationBPM * 0.35 + spectralBPM * 0.65)
        return Candidate(bpm: bpm, correlation: min(bestCorrelation, spectrum.quality))
    }

    private static func score(for lag: Int, correlations: [Double]) -> Double {
        let fundamentalSupport = lag * 2 < correlations.count ? correlations[lag * 2] * 0.35 : 0
        let lowerRatePreference = Double(lag) * 0.0005
        return correlations[lag] + fundamentalSupport + lowerRatePreference
    }

    private static func detrend(_ values: [Double], windowSize: Int) -> [Double] {
        values.indices.map { index in
            let start = max(0, index - windowSize)
            let end = min(values.count, index + windowSize + 1)
            let average = values[start..<end].reduce(0, +) / Double(end - start)
            return values[index] - average
        }
    }

    private static func smooth(_ values: [Double], radius: Int) -> [Double] {
        guard radius > 0 else { return values }
        return values.indices.map { index in
            let start = max(0, index - radius)
            let end = min(values.count, index + radius + 1)
            return values[start..<end].reduce(0, +) / Double(end - start)
        }
    }

    private static func parabolicPeak(at index: Int, in values: [Double]) -> Double {
        guard index > 0, index + 1 < values.count else { return Double(index) }
        let left = values[index - 1]
        let center = values[index]
        let right = values[index + 1]
        let denominator = left - (2 * center) + right
        guard abs(denominator) > 0.000001 else { return Double(index) }
        let offset = 0.5 * (left - right) / denominator
        return Double(index) + max(-0.45, min(0.45, offset))
    }

    private static func spectralCandidate(values: [Double], sampleRate: Double) -> (bpm: Double, quality: Double)? {
        guard values.count >= 100 else { return nil }
        let count = values.count
        let windowed = values.indices.map { index in
            let window = 0.5 * (1 - cos(2 * Double.pi * Double(index) / Double(count - 1)))
            return values[index] * window
        }
        let totalPower = windowed.reduce(0) { $0 + ($1 * $1) }
        guard totalPower > 0 else { return nil }

        let step = 0.01
        let minFrequency = 45.0 / 60.0
        let maxFrequency = 160.0 / 60.0
        let frequencies = Array(stride(from: minFrequency, through: maxFrequency, by: step))
        let powers = frequencies.map { frequency in
            var real = 0.0
            var imaginary = 0.0
            for index in 0..<count {
                let phase = 2 * Double.pi * frequency * Double(index) / sampleRate
                real += windowed[index] * cos(phase)
                imaginary -= windowed[index] * sin(phase)
            }
            return real * real + imaginary * imaginary
        }

        guard let bestIndex = powers.indices.max(by: { powers[$0] < powers[$1] }),
              bestIndex > 0,
              bestIndex + 1 < powers.count else { return nil }
        let refinedIndex = parabolicPeak(at: bestIndex, in: powers)
        let frequency = minFrequency + refinedIndex * step
        let quality = powers[bestIndex] / max(totalPower * Double(count), Double.leastNonzeroMagnitude)
        guard quality >= 0.018 else { return nil }
        return (frequency * 60, quality)
    }

    private static func correlation(at lag: Int, in values: [Double]) -> Double {
        let length = values.count - lag
        guard length > 2 else { return -1 }

        let left = values[0..<length]
        let right = values[lag..<(lag + length)]
        let leftMean = left.reduce(0, +) / Double(length)
        let rightMean = right.reduce(0, +) / Double(length)
        var numerator = 0.0
        var leftPower = 0.0
        var rightPower = 0.0

        for index in 0..<length {
            let l = left[left.startIndex + index] - leftMean
            let r = right[right.startIndex + index] - rightMean
            numerator += l * r
            leftPower += l * l
            rightPower += r * r
        }
        return numerator / sqrt(max(leftPower * rightPower, Double.leastNonzeroMagnitude))
    }
}
