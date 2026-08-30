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

    /// Default reference speed in km/h: 130 for Germany, 100 elsewhere.
    private static var defaultThresholdKMH: Double {
        Locale.current.region?.identifier == "DE" ? 130.0 : 100.0
    }

    var threshold: Double { // km/h (always stored in km/h)
        get { access(keyPath: \.threshold); return UserDefaults.standard.object(forKey: "threshold") as? Double ?? Self.defaultThresholdKMH }
        set { withMutation(keyPath: \.threshold) { UserDefaults.standard.set(newValue, forKey: "threshold") } }
    }

    var useMiles: Bool {
        get { access(keyPath: \.useMiles); return UserDefaults.standard.object(forKey: "useMiles") as? Bool ?? false }
        set {
            withMutation(keyPath: \.useMiles) { UserDefaults.standard.set(newValue, forKey: "useMiles") }
            threshold = newValue ? 80.4672 : Self.defaultThresholdKMH // 50 mph or 100/130 km/h
        }
    }

    var showPowerBand: Bool {
        get { access(keyPath: \.showPowerBand); return UserDefaults.standard.object(forKey: "showPowerBand") as? Bool ?? true }
        set { withMutation(keyPath: \.showPowerBand) { UserDefaults.standard.set(newValue, forKey: "showPowerBand") } }
    }

    /// Unit used to enter/display engine power. Global (vehicle power is stored in kW).
    var powerUnit: PowerUnit {
        get {
            access(keyPath: \.powerUnit)
            return UserDefaults.standard.string(forKey: "powerUnit").flatMap(PowerUnit.init(rawValue:)) ?? .horsepower
        }
        set { withMutation(keyPath: \.powerUnit) { UserDefaults.standard.set(newValue.rawValue, forKey: "powerUnit") } }
    }

    // MARK: - Vehicles
    //
    // The vehicle-specific physics parameters live on `Vehicle` values, and the
    // user can configure several. The whole list plus the active selection are
    // persisted (JSON in `UserDefaults`). The `carMass`/`frontalArea`/… facades
    // below map to the *active* vehicle, so the energy model and the settings
    // fields keep using them unchanged; switching cars instantly changes both.

    private static let vehiclesKey = "vehicles"
    private static let selectedVehicleIDKey = "selectedVehicleID"
    private static let nextVehicleNumberKey = "nextVehicleNumber"

    @ObservationIgnored private var _vehicles: [Vehicle] = []
    @ObservationIgnored private var _selectedVehicleID = UUID()

    var vehicles: [Vehicle] {
        get { access(keyPath: \.vehicles); return _vehicles }
        set { withMutation(keyPath: \.vehicles) { _vehicles = newValue; persistVehicles() } }
    }

    var selectedVehicleID: UUID {
        get { access(keyPath: \.selectedVehicleID); return _selectedVehicleID }
        set {
            withMutation(keyPath: \.selectedVehicleID) {
                _selectedVehicleID = newValue
                UserDefaults.standard.set(newValue.uuidString, forKey: Self.selectedVehicleIDKey)
            }
        }
    }

    /// The active vehicle. Always valid: the list is never empty and the
    /// selection is repaired at launch.
    var selectedVehicle: Vehicle {
        vehicles.first { $0.id == selectedVehicleID } ?? vehicles[0]
    }

    /// The active vehicle's editable name (empty means "use the default name").
    var selectedVehicleName: String {
        get { selectedVehicle.name }
        set { updateSelectedVehicle { $0.name = newValue } }
    }

    // Facades onto the active vehicle's physics parameters.
    var carMass: Double {
        get { selectedVehicle.carMass }
        set { updateSelectedVehicle { $0.carMass = newValue } }
    }
    var frontalArea: Double {
        get { selectedVehicle.frontalArea }
        set { updateSelectedVehicle { $0.frontalArea = newValue } }
    }
    var dragCoefficient: Double {
        get { selectedVehicle.dragCoefficient }
        set { updateSelectedVehicle { $0.dragCoefficient = newValue } }
    }
    var rollingResistanceCoeff: Double {
        get { selectedVehicle.rollingResistanceCoeff }
        set { updateSelectedVehicle { $0.rollingResistanceCoeff = newValue } }
    }
    var isElectric: Bool {
        get { selectedVehicle.isElectric }
        set { updateSelectedVehicle { $0.isElectric = newValue } }
    }
    var regenEfficiency: Double {
        get { selectedVehicle.regenEfficiency }
        set { updateSelectedVehicle { $0.regenEfficiency = newValue } }
    }
    var measuredPeakPowerKW: Double {
        get { selectedVehicle.measuredPeakPowerKW }
        set { updateSelectedVehicle { $0.measuredPeakPowerKW = newValue } }
    }

    /// Adds a new vehicle with default parameters and makes it active.
    func addVehicle() {
        let number = UserDefaults.standard.object(forKey: Self.nextVehicleNumberKey) as? Int ?? 1
        UserDefaults.standard.set(number + 1, forKey: Self.nextVehicleNumberKey)
        let vehicle = Vehicle(number: number)
        vehicles.append(vehicle)
        selectedVehicleID = vehicle.id
    }

    /// Removes the active vehicle (no-op if it is the last one) and selects a neighbour.
    func deleteSelectedVehicle() {
        guard vehicles.count > 1 else { return }
        var list = vehicles
        guard let idx = list.firstIndex(where: { $0.id == selectedVehicleID }) else { return }
        list.remove(at: idx)
        let neighbour = list[min(idx, list.count - 1)].id
        vehicles = list
        selectedVehicleID = neighbour
    }

    private func updateSelectedVehicle(_ body: (inout Vehicle) -> Void) {
        var list = vehicles
        guard let idx = list.firstIndex(where: { $0.id == selectedVehicleID }) else { return }
        body(&list[idx])
        vehicles = list
    }

    private func persistVehicles() {
        if let data = try? JSONEncoder().encode(_vehicles) {
            UserDefaults.standard.set(data, forKey: Self.vehiclesKey)
        }
    }

    /// Loads the persisted vehicle list, migrating a single-car config saved by
    /// an earlier version of the app, and repairs the active selection.
    private func bootstrapVehicles() {
        var loaded = Self.loadVehiclesFromDefaults()
        var counter = UserDefaults.standard.object(forKey: Self.nextVehicleNumberKey) as? Int ?? 1
        if loaded.isEmpty {
            loaded = [Self.migratedInitialVehicle(number: counter)]
            counter += 1
        }
        counter = max(counter, (loaded.map(\.number).max() ?? 0) + 1)

        let storedID = UserDefaults.standard.string(forKey: Self.selectedVehicleIDKey).flatMap { UUID(uuidString: $0) }
        let selected = (storedID.flatMap { id in loaded.contains { $0.id == id } ? id : nil }) ?? loaded[0].id

        _vehicles = loaded
        _selectedVehicleID = selected
        persistVehicles()
        UserDefaults.standard.set(counter, forKey: Self.nextVehicleNumberKey)
        UserDefaults.standard.set(selected.uuidString, forKey: Self.selectedVehicleIDKey)
    }

    private static func loadVehiclesFromDefaults() -> [Vehicle] {
        guard let data = UserDefaults.standard.data(forKey: vehiclesKey),
              let decoded = try? JSONDecoder().decode([Vehicle].self, from: data)
        else { return [] }
        return decoded
    }

    /// Builds the first vehicle, importing any single-car config saved by an
    /// earlier version (falling back to defaults otherwise).
    private static func migratedInitialVehicle(number: Int) -> Vehicle {
        let d = UserDefaults.standard
        return Vehicle(
            number: number,
            carMass: d.object(forKey: "carMass") as? Double ?? 1500.0,
            frontalArea: d.object(forKey: "frontalArea") as? Double ?? 2.2,
            dragCoefficient: d.object(forKey: "dragCoefficient") as? Double ?? 0.30,
            rollingResistanceCoeff: d.object(forKey: "rollingResistanceCoeff") as? Double ?? 0.012,
            isElectric: d.object(forKey: "isElectric") as? Bool ?? false,
            regenEfficiency: d.object(forKey: "regenEfficiency") as? Double ?? 0.70
        )
    }

    // MARK: - Transient runtime state (not persisted)

    var trafficJamMode = false // when on, extends auto-stop timeout to 1 hour
    private(set) var isDriving = false

    // Physics constants
    private let gravity: Double = 9.81 // m/s²
    private let drivetrainEfficiency = 0.85

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
    private let initialKalmanCovariance: Double = 1000
    private var kalmanEstimate: Double = 0
    private var kalmanErrorCovariance: Double = 1000
    private let kalmanProcessNoise: Double = 5000
    private let kalmanMeasurementNoise: Double = 20000

    private func kalmanFilter(_ measurement: Double) -> Double {
        // Predict (estimate stays the same, uncertainty grows)
        let predictedCovariance = kalmanErrorCovariance + kalmanProcessNoise

        // Update
        let kalmanGain = predictedCovariance / (predictedCovariance + kalmanMeasurementNoise)
        kalmanEstimate = kalmanEstimate + kalmanGain * (measurement - kalmanEstimate)
        kalmanErrorCovariance = (1 - kalmanGain) * predictedCovariance

        return kalmanEstimate
    }

    /// Adds engine work to an accumulator: positive work is added directly;
    /// negative work (braking) is partially recovered on EVs via regen.
    private func accumulateWork(_ work: Double, into accumulator: inout Double) {
        if work > 0 {
            accumulator += work
        } else if isElectric {
            accumulator += work * regenEfficiency
        }
    }

    var extraWorkPercentage: Double {
        guard cumulativeBaselineWork > 0 else { return 0 }
        return ((cumulativeActualWork - cumulativeBaselineWork) / cumulativeBaselineWork) * 100.0
    }

    private let manager = CLLocationManager()
    private var lastTimestamp: Date?
    private var lastMovingTimestamp: Date? // last time speed was > 0
    private let stopTimeout: TimeInterval = 120 // seconds at low speed before stopping
    private let trafficJamStopTimeout: TimeInterval = 3600 // 1 hour in Staumodus

    override init() {
        super.init()
        bootstrapVehicles()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = true
        manager.activityType = .automotiveNavigation
        applyLocationPowerMode(driving: false)
    }

    func start() {
        manager.requestAlwaysAuthorization()
        manager.startUpdatingLocation()
    }

    /// Adjusts location accuracy, distance filter, and auto-pause based on
    /// whether we are actively driving. When not driving, reduced accuracy and
    /// a distance filter save significant battery — especially in background.
    private func applyLocationPowerMode(driving: Bool) {
        if driving {
            manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            manager.distanceFilter = kCLDistanceFilterNone
            manager.pausesLocationUpdatesAutomatically = false
        } else {
            manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            manager.distanceFilter = 10
            manager.pausesLocationUpdatesAutomatically = true
        }
    }

    func reset() {
        timeSaved = 0
        travelTime = 0
        totalDistance = 0
        isDriving = false
        applyLocationPowerMode(driving: false)
        lastMovingTimestamp = nil
        cumulativeActualWork = 0
        cumulativeBaselineWork = 0
        instantaneousPower = 0
        kalmanEstimate = 0
        kalmanErrorCovariance = initialKalmanCovariance
        previousAltitude = nil
        previousSpeedMS = nil
    }

    func stopDriving() {
        isDriving = false
        applyLocationPowerMode(driving: false)
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.speed >= 0 else { return }

        MainActor.assumeIsolated {
            let speedKMH = location.speed * 3.6
            currentSpeed = speedKMH
            if !isDriving { instantaneousPower = 0 }

            // Driving state machine: start/reset when > 10 km/h, stop after timeout below 10 km/h
            if speedKMH > 10 {
                if !isDriving {
                    isDriving = true
                    applyLocationPowerMode(driving: true)
                }
                lastMovingTimestamp = location.timestamp
            } else if isDriving, let lastMoving = lastMovingTimestamp {
                let timeout = trafficJamMode ? trafficJamStopTimeout : stopTimeout
                let idleTime = location.timestamp.timeIntervalSince(lastMoving)
                if idleTime >= timeout {
                    travelTime = max(0, travelTime - idleTime)
                    isDriving = false
                    applyLocationPowerMode(driving: false)
                }
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

                        // Track all-time peak on the active vehicle (engine kW)
                        let engineKW = instantaneousPower / drivetrainEfficiency / 1000
                        if engineKW > measuredPeakPowerKW {
                            measuredPeakPowerKW = engineKW
                        }

                        // Accumulate actual engine work
                        accumulateWork(W_engine, into: &cumulativeActualWork)

                        // Baseline: what the engine would do at threshold speed
                        if speedMS > thresholdMS {
                            // Same distance dx, but at constant threshold speed (ΔKE = 0)
                            let W_drag_ref = 0.5 * rho * dragCoefficient * frontalArea * pow(thresholdMS, 2) * dx
                            let W_engine_ref = W_drag_ref + W_roll + W_gravity

                            accumulateWork(W_engine_ref, into: &cumulativeBaselineWork)
                        } else {
                            // Below threshold: baseline = actual
                            accumulateWork(W_engine, into: &cumulativeBaselineWork)
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
