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

    private let manager = CLLocationManager()
    private let threshold: Double = 130.0 // km/h
    private var lastTimestamp: Date?

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
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.speed >= 0 else { return }

        MainActor.assumeIsolated {
            let speedKMH = location.speed * 3.6
            currentSpeed = speedKMH

            if speedKMH > threshold, let last = lastTimestamp {
                let dt = location.timestamp.timeIntervalSince(last)
                if dt > 0, dt < 10 {
                    // Distance = speed * dt; time at 130 = distance / 130
                    // Time saved = dt * (actualSpeed / 130 - 1)
                    timeSaved += dt * (speedKMH / threshold - 1)
                }
            }

            lastTimestamp = location.timestamp
        }
    }
}
