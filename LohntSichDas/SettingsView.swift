//
//  SettingsView.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @Bindable var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    /// Which page of the vehicle pager is showing. Mirrors the active vehicle,
    /// except for the trailing "add a vehicle" page (tagged `addPageID`).
    @State private var pageSelection: UUID

    /// Sentinel tag for the trailing "add a vehicle" page.
    private static let addPageID = UUID()

    init(locationManager: LocationManager) {
        _locationManager = Bindable(locationManager)
        _pageSelection = State(initialValue: locationManager.selectedVehicleID)
    }

    private var displayThreshold: Double {
        locationManager.useMiles ? locationManager.threshold / 1.60934 : locationManager.threshold
    }

    private var sliderRange: ClosedRange<Double> {
        locationManager.useMiles ? 48.2802...193.121 : 50...200 // 30-120 mph or 50-200 km/h
    }

    private var sliderStep: Double {
        locationManager.useMiles ? 1.60934 : 5 // 1 mph steps or 5 km/h steps
    }

    private var speedUnit: String {
        locationManager.useMiles ? "mph" : "km/h"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Referenzgeschwindigkeit")
                        Spacer()
                        Text("\(Int(displayThreshold)) \(speedUnit)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $locationManager.threshold, in: sliderRange, step: sliderStep)
                } footer: {
                    Text("Zeitersparnis wird berechnet, wenn du schneller als \(Int(displayThreshold)) \(speedUnit) fährst.")
                }

                Section {
                    Picker("Einheit", selection: $locationManager.useMiles) {
                        Text("mph").tag(true)
                        Text("km/h").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TabView(selection: $pageSelection) {
                        ForEach(locationManager.vehicles) { vehicle in
                            VehicleEditor(vehicle: binding(for: vehicle))
                                .padding(.bottom, 28) // leave room for the page dots
                                .tag(vehicle.id)
                        }
                        AddVehiclePage {
                            locationManager.addVehicle()
                            pageSelection = locationManager.selectedVehicleID
                        }
                        .tag(Self.addPageID)
                    }
                    .frame(height: 380)
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("Fahrzeug")
                } footer: {
                    Text("Wische seitwärts, um zwischen Fahrzeugen zu wechseln oder ein neues hinzuzufügen.")
                }

                if locationManager.vehicles.count > 1 {
                    Section {
                        Button(role: .destructive) {
                            locationManager.deleteSelectedVehicle()
                            pageSelection = locationManager.selectedVehicleID
                        } label: {
                            Text("Dieses Auto löschen")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
            .onChange(of: pageSelection) { _, newValue in
                // Swiping to a real vehicle page makes it the active vehicle;
                // the trailing "add" page leaves the selection unchanged.
                if locationManager.vehicles.contains(where: { $0.id == newValue }) {
                    locationManager.selectedVehicleID = newValue
                }
            }
        }
    }

    /// A binding into a specific vehicle in the manager's list, so each page
    /// edits its own car regardless of which one is currently active.
    private func binding(for vehicle: Vehicle) -> Binding<Vehicle> {
        Binding(
            get: { locationManager.vehicles.first(where: { $0.id == vehicle.id }) ?? vehicle },
            set: { newValue in
                if let idx = locationManager.vehicles.firstIndex(where: { $0.id == vehicle.id }) {
                    locationManager.vehicles[idx] = newValue
                }
            }
        )
    }
}

/// The editable fields for a single vehicle, laid out as one page of the pager.
private struct VehicleEditor: View {
    @Binding var vehicle: Vehicle

    private var regenPercent: Binding<Double> {
        Binding(
            get: { vehicle.regenEfficiency * 100 },
            set: { vehicle.regenEfficiency = $0 / 100 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            row("Name") {
                TextField("Auto #\(vehicle.number)", text: $vehicle.name)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }
            Divider()
            numberRow("Fahrzeugmasse", value: $vehicle.carMass, fraction: 0, unit: "kg", keyboard: .numberPad)
            Divider()
            numberRow("Stirnfläche", value: $vehicle.frontalArea, fraction: 1, unit: "m²", keyboard: .decimalPad)
            Divider()
            numberRow("Cw-Wert", value: $vehicle.dragCoefficient, fraction: 2, unit: nil, keyboard: .decimalPad)
            Divider()
            numberRow("Rollwiderstand", value: $vehicle.rollingResistanceCoeff, fraction: 3, unit: nil, keyboard: .decimalPad)
            Divider()
            Toggle("Elektrofahrzeug", isOn: $vehicle.isElectric)
                .padding(.vertical, 10)
            if vehicle.isElectric {
                Divider()
                numberRow("Rekuperationseffizienz", value: regenPercent, fraction: 0, unit: "%", keyboard: .numberPad)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
            Spacer()
            content()
        }
        .padding(.vertical, 10)
    }

    private func numberRow(_ label: String, value: Binding<Double>, fraction: Int, unit: String?, keyboard: UIKeyboardType) -> some View {
        row(label) {
            TextField(label, value: value, format: SystemNumberStyle(fractionDigits: fraction))
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 80)
            if let unit {
                Text(unit).foregroundStyle(.secondary)
            }
        }
    }
}

/// The trailing pager page: a single button that adds a new vehicle.
private struct AddVehiclePage: View {
    let action: () -> Void

    var body: some View {
        VStack {
            Spacer()
            Button(action: action) {
                Label("Auto hinzufügen", systemImage: "plus.circle.fill")
                    .font(.title3.weight(.medium))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 28)
    }
}
