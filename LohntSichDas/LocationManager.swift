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

    var threshold: Double = 130.0 // km/h (always stored in km/h)
    var useMiles = false {
        didSet {
            threshold = useMiles ? 96.5606 : 130.0 // 60 mph or 130 km/h
        }
    }
    var trafficJamMode = false // when on, drive time never auto-stops
    private(set) var isDriving = false

    // Physics model parameters (configurable)
    var carMass: Double = 1500.0 // kg
    var frontalArea: Double = 2.2 // m²
    var dragCoefficient: Double = 0.30 // Cd (Cw-Wert)
    var rollingResistanceCoeff: Double = 0.012 // Cr
    var drivetrainEfficiency: Double = 0.85 // η

    // Physics constants
    private let airDensity: Double = 1.225 // kg/m³ at sea level, 15°C
    private let gravity: Double = 9.81 // m/s²

    // Energy accumulators (Joules)
    var cumulativeExtraWork: Double = 0
    var cumulativeBaselineWork: Double = 0
    private var previousAltitude: Double?

    var extraWorkPercentage: Double {
        guard cumulativeBaselineWork > 0 else { return 0 }
        return (cumulativeExtraWork / cumulativeBaselineWork) * 100.0
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
        cumulativeExtraWork = 0
        cumulativeBaselineWork = 0
        previousAltitude = nil
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

                        // Energy calculation
                        let thresholdMS = threshold / 3.6
                        let effectiveSpeed = min(speedMS, thresholdMS)

                        // Baseline drag work (at capped speed, over actual distance)
                        let baselineDrag = 0.5 * airDensity * dragCoefficient * frontalArea * pow(effectiveSpeed, 2) * dx

                        // Rolling resistance work (same for both, part of baseline total)
                        let rollingWork = rollingResistanceCoeff * carMass * gravity * dx

                        // Altitude work (same for both, part of baseline total)
                        var altitudeWork = 0.0
                        if let prevAlt = previousAltitude, location.verticalAccuracy >= 0 {
                            let dh = location.altitude - prevAlt
                            altitudeWork = carMass * gravity * dh
                        }

                        cumulativeBaselineWork += baselineDrag + rollingWork + altitudeWork

                        // Extra drag work (only when exceeding threshold)
                        if speedKMH > threshold {
                            let extraDrag = 0.5 * airDensity * dragCoefficient * frontalArea * (pow(speedMS, 2) - pow(thresholdMS, 2)) * dx
                            cumulativeExtraWork += extraDrag
                        }
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
