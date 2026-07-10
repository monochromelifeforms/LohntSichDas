//
//  Vehicle.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import Foundation

/// Unit in which engine power is entered/displayed. Storage is always kW.
enum PowerUnit: String, CaseIterable, Identifiable, Codable {
    case kilowatt
    case horsepower       // mechanical / imperial HP
    case metricHorsepower // metric PS

    var id: String { rawValue }

    /// Short UI label.
    var label: String {
        switch self {
        case .kilowatt: "kW"
        case .horsepower: "HP"
        case .metricHorsepower: "PS"
        }
    }

    /// Kilowatts represented by one unit of this kind.
    var kilowattsPerUnit: Double {
        switch self {
        case .kilowatt: 1.0
        case .horsepower: 0.745699872
        case .metricHorsepower: 0.73549875
        }
    }
}

/// A configurable vehicle: a name plus the physics parameters used by the
/// energy model. Reference speed and unit are *not* here — they are global app
/// settings that apply regardless of the active vehicle.
struct Vehicle: Identifiable, Codable, Hashable {
    /// Default engine power for a new vehicle: 100 HP, stored in kW.
    static let defaultPowerKW = 100 * PowerUnit.horsepower.kilowattsPerUnit

    let id: UUID
    /// Running number assigned at creation; used for the default display name.
    let number: Int
    /// User-provided name. When empty, `displayName` falls back to "Auto #<number>".
    var name: String

    var power: Double                   // kW (engine/crank power)
    var carMass: Double                 // kg
    var frontalArea: Double             // m²
    var dragCoefficient: Double         // Cd (Cw-Wert)
    var rollingResistanceCoeff: Double  // Cr
    var isElectric: Bool
    var regenEfficiency: Double         // fraction of braking energy recovered (EV only)

    init(
        id: UUID = UUID(),
        number: Int,
        name: String = "",
        power: Double = Vehicle.defaultPowerKW,
        carMass: Double = 1500.0,
        frontalArea: Double = 2.2,
        dragCoefficient: Double = 0.30,
        rollingResistanceCoeff: Double = 0.012,
        isElectric: Bool = false,
        regenEfficiency: Double = 0.70
    ) {
        self.id = id
        self.number = number
        self.name = name
        self.power = power
        self.carMass = carMass
        self.frontalArea = frontalArea
        self.dragCoefficient = dragCoefficient
        self.rollingResistanceCoeff = rollingResistanceCoeff
        self.isElectric = isElectric
        self.regenEfficiency = regenEfficiency
    }

    private enum CodingKeys: String, CodingKey {
        case id, number, name, power, carMass, frontalArea
        case dragCoefficient, rollingResistanceCoeff, isElectric, regenEfficiency
    }

    // Custom decoder so vehicles saved before `power` existed still load
    // (missing power falls back to the default).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        number = try c.decode(Int.self, forKey: .number)
        name = try c.decode(String.self, forKey: .name)
        power = try c.decodeIfPresent(Double.self, forKey: .power) ?? Vehicle.defaultPowerKW
        carMass = try c.decode(Double.self, forKey: .carMass)
        frontalArea = try c.decode(Double.self, forKey: .frontalArea)
        dragCoefficient = try c.decode(Double.self, forKey: .dragCoefficient)
        rollingResistanceCoeff = try c.decode(Double.self, forKey: .rollingResistanceCoeff)
        isElectric = try c.decode(Bool.self, forKey: .isElectric)
        regenEfficiency = try c.decode(Double.self, forKey: .regenEfficiency)
    }

    /// Name shown in the UI: the user's name, or "Auto #<number>" when unnamed.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Auto #\(number)" : trimmed
    }
}
