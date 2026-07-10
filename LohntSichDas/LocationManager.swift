//
//  LocationManager.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import CoreLocation
import Observation

@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    var currentSpeed: Double = 0 // km/h
    var timeSaved: TimeInterval = 0 // seconds
    var travelTime: TimeInterval = 0 // seconds of driving
    var totalDistance: Double = 0 // meters driven during travelTime

    var averageSpeed: Double { // km/h
        guard travelTime > 0 else { return 0 }
        return (totalDistance / travelTime) * 3.6
    }

    // MARK: - Persisted settings
    //
    // Every user-configurable setting is a computed property backed by
    // `UserDefaults`, so it is saved the instant it changes and restored on the
    // next launch. To add a new setting, copy the template below: a computed
    // property that reads/writes `UserDefaults` and wraps the access in
    // `access(keyPath:)` / `withMutation(keyPath:)` so `@Observable` keeps
    // tracking it. The default value lives inline in the getter — that is the
    // only place it needs to be defined.

    var threshold: Double { // km/h (always stored in km/h)
        get { access(keyPath: \.threshold); return UserDefaults.standard.object(forKey: "threshold") as? Double ?? 130.0 }
        set { withMutation(keyPath: \.threshold) { UserDefaults.standard.set(newValue, forKey: "threshold") } }
    }

    var useMiles: Bool {
        get { access(keyPath: \.useMiles); return UserDefaults.standard.object(forKey: "useMiles") as? Bool ?? false }
        set {
            withMutation(keyPath: \.useMiles) { UserDefaults.standard.set(newValue, forKey: "useMiles") }
            threshold = newValue ? 96.5606 : 130.0 // reset reference to 60 mph or 130 km/h
        }
    }

    var carMass: Double { // kg
        get { access(keyPath: \.carMass); return UserDefaults.standard.object(forKey: "carMass") as? Double ?? 1500.0 }
        set { withMutation(keyPath: \.carMass) { UserDefaults.standard.set(newValue, forKey: "carMass") } }
    }

    var frontalArea: Double { // m²
        get { access(keyPath: \.frontalArea); return UserDefaults.standard.object(forKey: "frontalArea") as? Double ?? 2.2 }
        set { withMutation(keyPath: \.frontalArea) { UserDefaults.standard.set(newValue, forKey: "frontalArea") } }
    }

    var dragCoefficient: Double { // Cd (Cw-Wert)
        get { access(keyPath: \.dragCoefficient); return UserDefaults.standard.object(forKey: "dragCoefficient") as? Double ?? 0.30 }
        set { withMutation(keyPath: \.dragCoefficient) { UserDefaults.standard.set(newValue, forKey: "dragCoefficient") } }
    }

    var rollingResistanceCoeff: Double { // Cr
        get { access(keyPath: \.rollingResistanceCoeff); return UserDefaults.standard.object(forKey: "rollingResistanceCoeff") as? Double ?? 0.012 }
        set { withMutation(keyPath: \.rollingResistanceCoeff) { UserDefaults.standard.set(newValue, forKey: "rollingResistanceCoeff") } }
    }

    var isElectric: Bool {
        get { access(keyPath: \.isElectric); return UserDefaults.standard.object(forKey: "isElectric") as? Bool ?? false }
        set { withMutation(keyPath: \.isElectric) { UserDefaults.standard.set(newValue, forKey: "isElectric") } }
    }

    var regenEfficiency: Double { // fraction of braking energy recovered (EV only)
        get { access(keyPath: \.regenEfficiency); return UserDefaults.standard.object(forKey: "regenEfficiency") as? Double ?? 0.70 }
        set { withMutation(keyPath: \.regenEfficiency) { UserDefaults.standard.set(newValue, forKey: "regenEfficiency") } }
    }

    // MARK: - Transient runtime state (not persisted)

    var trafficJamMode = false // when on, drive time never auto-stops
    private(set) var isDriving = false

    // Physics constants
    private let gravity: Double = 9.81 // m/s²

    /// Air density from the International Standard Atmosphere (ISA) model.
    /// Valid for the troposphere (altitude < 11 km).
    /// ρ(h) = ρ₀ × (1 − L·h / T₀)^(g·M/(R·L) − 1)
    private func airDensity(atAltitude h: Double) -> Double {
        let rho0 = 1.225       // kg/m³, sea level
        let T0 = 288.15        // K, sea level temperature
        let L = 0.0065         // K/m, temperature lapse rate
        let gM_RL = 5.2559     // g·M/(R·L), dimensionless exponent
        let base = 1.0 - L * h / T0
        guard base > 0 else { return 0.3 } // above ~44 km, clamp to small value
        return rho0 * pow(base, gM_RL - 1.0)
    }

    // Energy accumulators (Joules)
    var cumulativeActualWork: Double = 0
    var cumulativeBaselineWork: Double = 0
    var instantaneousPower: Double = 0 // Watts (W_engine / dt), Kalman-filtered
    private var previousAltitude: Double?
    private var previousSpeedMS: Double? // for KE delta calculation

    // Kalman filter state for instantaneous power
    private var kalmanEstimate: Double = 0
    private var kalmanErrorCovariance: Double = 1000 // start with high uncertainty
    private let kalmanProcessNoise: Double = 5000 // how much we expect power to change between samples
    private let kalmanMeasurementNoise: Double = 20000 // how noisy raw readings are

    private func kalmanFilter(_ measurement: Double) -> Double {
        // Predict (estimate stays the same, uncertainty grows)
        let predictedCovariance = kalmanErrorCovariance + kalmanProcessNoise

        // Update
        let kalmanGain = predictedCovariance / (predictedCovariance + kalmanMeasurementNoise)
        kalmanEstimate = kalmanEstimate + kalmanGain * (measurement - kalmanEstimate)
        kalmanErrorCovariance = (1 - kalmanGain) * predictedCovariance

        return kalmanEstimate
    }

    var extraWorkPercentage: Double {
        guard cumulativeBaselineWork > 0 else { return 0 }
        return ((cumulativeActualWork - cumulativeBaselineWork) / cumulativeBaselineWork) * 100.0
    }

    private let manager = CLLocationManager()
    private var lastTimestamp: Date?
    private var lastMovingTimestamp: Date? // last time speed was > 0
    private let stopTimeout: TimeInterval = 60 // seconds at zero before stopping

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .automotiveNavigation
    }

    func start() {
        manager.requestAlwaysAuthorization()
        manager.startUpdatingLocation()
    }

    func reset() {
        timeSaved = 0
        travelTime = 0
        totalDistance = 0
        isDriving = false
        lastMovingTimestamp = nil
        cumulativeActualWork = 0
        cumulativeBaselineWork = 0
        instantaneousPower = 0
        kalmanEstimate = 0
        kalmanErrorCovariance = 1000
        previousAltitude = nil
        previousSpeedMS = nil
    }

    func stopDriving() {
        isDriving = false
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.speed >= 0 else { return }

        MainActor.assumeIsolated {
            let speedKMH = location.speed * 3.6
            currentSpeed = speedKMH
            if !isDriving { instantaneousPower = 0 }

            // Driving state machine: start when > 8 km/h, stop after 60s at zero
            if speedKMH > 10 {
                if !isDriving {
                    isDriving = true
                }
                lastMovingTimestamp = location.timestamp
            } else if speedKMH < 6, isDriving, !trafficJamMode, let lastMoving = lastMovingTimestamp {
                if location.timestamp.timeIntervalSince(lastMoving) >= stopTimeout {
                    isDriving = false
                }
            } else if speedKMH >= 6 {
                // Between 6 and 8: not enough to start driving, but resets the stop timer
                lastMovingTimestamp = location.timestamp
            }

            if let last = lastTimestamp {
                let dt = location.timestamp.timeIntervalSince(last)
                if dt > 0, dt < 10 {
                    let speedMS = location.speed // m/s
                    let dx = speedMS * dt // distance in meters

                    if isDriving {
                        travelTime += dt
                        totalDistance += dx

                        // --- Energy model (Newton / work-energy theorem) ---
                        // W_engine = ΔKE + W_drag + W_roll + W_gravity
                        // Positive W_engine = engine consuming fuel
                        // Negative W_engine = braking (lost on ICE, partially recovered on EV)

                        let thresholdMS = threshold / 3.6
                        let rho = airDensity(atAltitude: location.altitude)

                        // Work against aerodynamic drag
                        let W_drag = 0.5 * rho * dragCoefficient * frontalArea * pow(speedMS, 2) * dx

                        // Work against rolling resistance
                        let W_roll = rollingResistanceCoeff * carMass * gravity * dx

                        // Work against gravity (positive uphill, negative downhill)
                        var W_gravity = 0.0
                        if let prevAlt = previousAltitude, location.verticalAccuracy >= 0 {
                            W_gravity = carMass * gravity * (location.altitude - prevAlt)
                        }

                        // Change in kinetic energy
                        var deltaKE = 0.0
                        if let prevSpeed = previousSpeedMS {
                            deltaKE = 0.5 * carMass * (pow(speedMS, 2) - pow(prevSpeed, 2))
                        }

                        // Total engine work for this step
                        let W_engine = deltaKE + W_drag + W_roll + W_gravity
                        instantaneousPower = kalmanFilter(W_engine / dt)

                        // Accumulate actual engine work
                        if W_engine > 0 {
                            cumulativeActualWork += W_engine
                        } else if isElectric {
                            // Regenerative braking recovers energy
                            cumulativeActualWork += W_engine * regenEfficiency
                        }
                        // ICE with W_engine <= 0: coasting/braking, no fuel consumed

                        // Baseline: what the engine would do at threshold speed
                        if speedMS > thresholdMS {
                            // Same distance dx, but at constant threshold speed (ΔKE = 0)
                            let W_drag_ref = 0.5 * rho * dragCoefficient * frontalArea * pow(thresholdMS, 2) * dx
                            let W_engine_ref = W_drag_ref + W_roll + W_gravity

                            if W_engine_ref > 0 {
                                cumulativeBaselineWork += W_engine_ref
                            } else if isElectric {
                                cumulativeBaselineWork += W_engine_ref * regenEfficiency
                            }
                        } else {
                            // Below threshold: baseline = actual
                            if W_engine > 0 {
                                cumulativeBaselineWork += W_engine
                            } else if isElectric {
                                cumulativeBaselineWork += W_engine * regenEfficiency
                            }
                        }

                        previousSpeedMS = speedMS
                    }

                    if speedKMH > threshold {
                        timeSaved += dt * (speedKMH / threshold - 1)
                    }
                }
            }

            if location.verticalAccuracy >= 0 {
                previousAltitude = location.altitude
            }
            lastTimestamp = location.timestamp
        }
    }
}
