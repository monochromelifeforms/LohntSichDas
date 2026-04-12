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

    var threshold: Double = 130.0 // km/h
    var trafficJamMode = false // when on, drive time never auto-stops
    private(set) var isDriving = false

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
                    if isDriving {
                        travelTime += dt
                        totalDistance += location.speed * dt
                    }
                    if speedKMH > threshold {
                        // Distance = speed * dt; time at 130 = distance / 130
                        // Time saved = dt * (actualSpeed / 130 - 1)
                        timeSaved += dt * (speedKMH / threshold - 1)
                    }
                }
            }

            lastTimestamp = location.timestamp
        }
    }
}
