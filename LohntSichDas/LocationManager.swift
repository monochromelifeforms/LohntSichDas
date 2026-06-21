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
    var isElectric: Bool = false
    var regenEfficiency: Double = 0.70 // fraction of braking energy recovered (EV only)

    // Physics constants
    private let airDensity: Double = 1.225 // kg/m³ at sea level, 15°C
    private let gravity: Double = 9.81 // m/s²

    // Energy accumulators (Joules)
    var cumulativeActualWork: Double = 0
    var cumulativeBaselineWork: Double = 0
    private var previousAltitude: Double?
    private var previousSpeedMS: Double? // for KE delta calculation

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
                        let baselineSpeed = min(speedMS, thresholdMS)

                        // Drag work
                        let dragActual = 0.5 * airDensity * dragCoefficient * frontalArea * pow(speedMS, 2) * dx
                        let dragBaseline = 0.5 * airDensity * dragCoefficient * frontalArea * pow(baselineSpeed, 2) * dx

                        // Rolling resistance (same for both)
                        let rollingWork = rollingResistanceCoeff * carMass * gravity * dx

                        // Altitude work (same for both)
                        var altitudeWork = 0.0
                        if let prevAlt = previousAltitude, location.verticalAccuracy >= 0 {
                            let dh = location.altitude - prevAlt
                            altitudeWork = carMass * gravity * dh
                        }

                        // Kinetic energy changes
                        var keActual = 0.0
                        var keBaseline = 0.0
                        if let prevSpeed = previousSpeedMS {
                            let dKE = 0.5 * carMass * (pow(speedMS, 2) - pow(prevSpeed, 2))
                            let prevBaseline = min(prevSpeed, thresholdMS)
                            let dKEBaseline = 0.5 * carMass * (pow(baselineSpeed, 2) - pow(prevBaseline, 2))

                            // KE increase = engine work; KE decrease = brake heat (ICE) or partial recovery (EV)
                            if dKE > 0 {
                                keActual = dKE
                            } else if isElectric {
                                keActual = dKE * regenEfficiency // negative → reduces work
                            }

                            if dKEBaseline > 0 {
                                keBaseline = dKEBaseline
                            } else if isElectric {
                                keBaseline = dKEBaseline * regenEfficiency
                            }
                        }

                        cumulativeActualWork += dragActual + rollingWork + altitudeWork + keActual
                        cumulativeBaselineWork += dragBaseline + rollingWork + altitudeWork + keBaseline

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
