//
//  PowerScale.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import Foundation

/// Computes adaptive tick intervals for a circular power band so that there
/// are roughly 5–10 major ticks per side regardless of whether the scale
/// represents 85 W (cycling) or 1,275,000 W (hypercar).
struct PowerScale {

    struct Tick: Identifiable {
        let id: Int
        /// Power in watts that this tick represents.
        let power: Double
        /// Angle in degrees clockwise from 12 o'clock.
        let angleDegrees: Double
        /// Whether this is a major (long) tick or a minor (short) tick.
        let isMajor: Bool
    }

    /// Full-scale power in watts (end of the grey arc).
    let powerBandScale: Double

    /// Fraction of the circle occupied by the band on one side (default 0.39).
    let maxBandFraction: Double

    /// Major tick interval in watts, chosen via the 1-2-5 "nice number" rule.
    let majorInterval: Double

    /// Minor tick interval in watts (subdivides a major interval).
    let minorInterval: Double

    /// All ticks from `minorInterval` up to `powerBandScale`.
    let ticks: [Tick]

    /// The major tick nearest the ~130° (4-5 o'clock) position.
    let labeledTickPower: Double

    /// Formatted label for the labeled tick (e.g. "80 kW" or "50 W").
    let labelText: String

    init(powerBandScale: Double, maxBandFraction: Double = 0.39) {
        self.powerBandScale = powerBandScale
        self.maxBandFraction = maxBandFraction

        let maxBandDeg = maxBandFraction * 360

        // --- Nice-number algorithm for ~7 major ticks ---
        let rawStep = powerBandScale / 7
        let exponent = floor(log10(rawStep))
        let mantissa = rawStep / pow(10, exponent)

        let niceMantissa: Double
        let minorSubdivisions: Double
        if mantissa <= 1.5 {
            niceMantissa = 1; minorSubdivisions = 5
        } else if mantissa <= 3.5 {
            niceMantissa = 2; minorSubdivisions = 4
        } else if mantissa <= 7.5 {
            niceMantissa = 5; minorSubdivisions = 5
        } else {
            niceMantissa = 10; minorSubdivisions = 5
        }

        let major = niceMantissa * pow(10, exponent)
        let minor = major / minorSubdivisions
        self.majorInterval = major
        self.minorInterval = minor

        // --- Build ticks ---
        var built: [Tick] = []
        var index = 0
        var power = minor
        while power <= powerBandScale {
            let angleDeg = power / powerBandScale * maxBandDeg
            let isMajor = power.remainder(dividingBy: major).magnitude < minor * 0.1
            built.append(Tick(id: index, power: power, angleDegrees: angleDeg, isMajor: isMajor))
            index += 1
            power += minor
        }
        self.ticks = built

        // --- Labeled tick: major tick nearest 130° ---
        let targetDeg = 130.0
        let majorTicks = built.filter { $0.isMajor }
        if let closest = majorTicks.min(by: { abs($0.angleDegrees - targetDeg) < abs($1.angleDegrees - targetDeg) }) {
            self.labeledTickPower = closest.power
        } else {
            self.labeledTickPower = 0
        }

        // --- Format label ---
        if labeledTickPower >= 1000 {
            let kW = Int(labeledTickPower / 1000)
            self.labelText = "\(kW) kW"
        } else {
            let w = Int(labeledTickPower)
            self.labelText = "\(w) W"
        }
    }
}
