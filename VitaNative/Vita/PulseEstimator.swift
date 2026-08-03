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
            return "Vita could not find a stable pulse signal."
        }
    }
}

enum PulseEstimator {
    static func estimate(from samples: [PulseSample]) -> Double? {
        guard samples.count >= 100,
              let first = samples.first,
              let last = samples.last else { return nil }

        let duration = last.time - first.time
        guard duration > 5 else { return nil }
        let sampleRate = Double(samples.count - 1) / duration
        let values = samples.map(\.value)
        let normalized = detrend(values, windowSize: max(8, Int(sampleRate * 0.8)))
        let signalEnergy = sqrt(normalized.reduce(0) { $0 + ($1 * $1) } / Double(normalized.count))
        guard signalEnergy > 0.0003 else { return nil }

        var bestLag = 0
        var bestCorrelation = -1.0
        let minLag = max(2, Int(sampleRate * 60 / 180))
        let maxLag = Int(ceil(sampleRate * 60 / 42))

        for lag in minLag...min(maxLag, normalized.count / 2 - 1) {
            let correlation = correlation(at: lag, in: normalized)
            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestLag = lag
            }
        }

        guard bestLag > 0, bestCorrelation >= 0.18 else { return nil }
        let bpm = (60 * sampleRate / Double(bestLag)).rounded()
        guard (42...180).contains(bpm) else { return nil }
        return bpm
    }

    private static func detrend(_ values: [Double], windowSize: Int) -> [Double] {
        values.indices.map { index in
            let start = max(0, index - windowSize)
            let end = min(values.count, index + windowSize + 1)
            let average = values[start..<end].reduce(0, +) / Double(end - start)
            return values[index] - average
        }
    }

    private static func correlation(at lag: Int, in values: [Double]) -> Double {
        let length = values.count - lag
        guard length > 2 else { return -1 }
        let left = Array(values[0..<length])
        let right = Array(values[lag..<(lag + length)])
        let leftMean = left.reduce(0, +) / Double(length)
        let rightMean = right.reduce(0, +) / Double(length)
        var numerator = 0.0
        var leftPower = 0.0
        var rightPower = 0.0

        for index in 0..<length {
            let l = left[index] - leftMean
            let r = right[index] - rightMean
            numerator += l * r
            leftPower += l * l
            rightPower += r * r
        }
        return numerator / sqrt(max(leftPower * rightPower, Double.leastNonzeroMagnitude))
    }
}
