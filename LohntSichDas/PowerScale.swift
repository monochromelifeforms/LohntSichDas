//
//  PowerScale.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import Foundation

/// Computes adaptive tick intervals for a circular power band so that there
/// are roughly 5–10 ticks per side regardless of whether the scale represents
/// 85 W (cycling) or 1,275,000 W (hypercar).
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

    /// Tick interval in watts, chosen via the 1-2-5 "nice number" rule to
    /// produce roughly 5–10 ticks per side.
    let tickInterval: Double

    /// Every `majorEvery`-th tick is drawn longer (major).
    let majorEvery: Int

    /// All ticks from `tickInterval` up to `powerBandScale`.
    let ticks: [Tick]

    /// The tick nearest the ~130° (4-5 o'clock) position that carries the label.
    let labeledTickPower: Double

    /// Formatted label for the labeled tick (e.g. "60 kW" or "50 W").
    let labelText: String

    init(powerBandScale: Double, maxBandFraction: Double = 0.39) {
        self.powerBandScale = powerBandScale
        self.maxBandFraction = maxBandFraction

        let maxBandDeg = maxBandFraction * 360

        // --- Nice-number algorithm targeting ~7 ticks total per side ---
        let rawStep = powerBandScale / 7
        let exponent = floor(log10(rawStep))
        let mantissa = rawStep / pow(10, exponent)

        let niceMantissa: Double
        let majorN: Int
        if mantissa <= 1.5 {
            niceMantissa = 1; majorN = 5   // major at 5×, e.g. 50, 500
        } else if mantissa <= 3.5 {
            niceMantissa = 2; majorN = 5   // major at 10×, e.g. 100, 1000
        } else if mantissa <= 7.5 {
            niceMantissa = 5; majorN = 2   // major at 10×, e.g. 100, 1000
        } else {
            niceMantissa = 10; majorN = 5  // major at 50×, e.g. 500, 5000
        }

        let interval = niceMantissa * pow(10, exponent)
        self.tickInterval = interval
        self.majorEvery = majorN

        let majorInterval = interval * Double(majorN)

        // --- Build ticks ---
        var built: [Tick] = []
        var index = 0
        var power = interval
        while power <= powerBandScale {
            let angleDeg = power / powerBandScale * maxBandDeg
            let isMajor = power.remainder(dividingBy: majorInterval).magnitude < interval * 0.1
            built.append(Tick(id: index, power: power, angleDegrees: angleDeg, isMajor: isMajor))
            index += 1
            power += interval
        }
        self.ticks = built

        // --- Labeled tick: nearest tick to ~130° ---
        let targetDeg = 130.0
        if let closest = built.min(by: { abs($0.angleDegrees - targetDeg) < abs($1.angleDegrees - targetDeg) }) {
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
