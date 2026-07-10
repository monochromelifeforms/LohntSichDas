//
//  Vehicle.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import Foundation

/// A configurable vehicle: a name plus the physics parameters used by the
/// energy model. Reference speed and unit are *not* here — they are global app
/// settings that apply regardless of the active vehicle.
struct Vehicle: Identifiable, Codable, Hashable {
    let id: UUID
    /// Running number assigned at creation; used for the default display name.
    let number: Int
    /// User-provided name. When empty, `displayName` falls back to "Auto #<number>".
    var name: String

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
        self.carMass = carMass
        self.frontalArea = frontalArea
        self.dragCoefficient = dragCoefficient
        self.rollingResistanceCoeff = rollingResistanceCoeff
        self.isElectric = isElectric
        self.regenEfficiency = regenEfficiency
    }

    /// Name shown in the UI: the user's name, or "Auto #<number>" when unnamed.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Auto #\(number)" : trimmed
    }
}
