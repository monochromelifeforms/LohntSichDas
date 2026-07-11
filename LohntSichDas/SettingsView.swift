//
//  SettingsView.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import SwiftUI

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
                            VehicleEditor(vehicle: binding(for: vehicle),
                                          powerUnit: $locationManager.powerUnit)
                                .padding(.bottom, 28) // leave room for the page dots
                                .tag(vehicle.id)
                        }
                        AddVehiclePage {
                            locationManager.addVehicle()
                            pageSelection = locationManager.selectedVehicleID
                        }
                        .tag(Self.addPageID)
                    }
                    .frame(height: 390)
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
                            Text("Dieses Fahrzeug löschen")
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
    @Binding var powerUnit: PowerUnit

    private enum Field: Hashable {
        case name, power, mass, frontalArea, drag, rolling, regen
    }
    @FocusState private var focused: Field?

    private var regenPercent: Binding<Double> {
        Binding(
            get: { vehicle.regenEfficiency * 100 },
            set: { vehicle.regenEfficiency = $0 / 100 }
        )
    }

    /// The power in the currently selected unit (storage is always kW).
    private var powerInUnit: Binding<Double> {
        Binding(
            get: { vehicle.power / powerUnit.kilowattsPerUnit },
            set: { vehicle.power = $0 * powerUnit.kilowattsPerUnit }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            row(.name, "Name") {
                TextField("Auto #\(vehicle.number)", text: $vehicle.name)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
                    .focused($focused, equals: .name)
            }
            Divider()
            row(.power, "Leistung") {
                // Power is rounded to 2 decimals (enough for kW/HP/PS, incl. when
                // converting between units); other fields allow arbitrary decimals.
                DecimalField(value: powerInUnit, maxFractionDigits: 2,
                             focus: $focused, field: .power)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 70)
                Picker("Einheit", selection: $powerUnit) {
                    ForEach(PowerUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
            Divider()
            numberRow(.mass, "Fahrzeugmasse", value: $vehicle.carMass, unit: "kg")
            Divider()
            numberRow(.frontalArea, "Stirnfläche", value: $vehicle.frontalArea, unit: "m²")
            Divider()
            numberRow(.drag, "Cw-Wert", value: $vehicle.dragCoefficient, unit: nil)
            Divider()
            numberRow(.rolling, "Rollwiderstand", value: $vehicle.rollingResistanceCoeff, unit: nil)
            Divider()
            Toggle("Elektrofahrzeug", isOn: $vehicle.isElectric)
                .padding(.vertical, 10)
            if vehicle.isElectric {
                Divider()
                numberRow(.regen, "Rekuperationseffizienz", value: regenPercent, unit: "%")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
    }

    private func row<Content: View>(_ field: Field, _ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
            Spacer()
            content()
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        // Tapping anywhere on the row focuses its field — a much larger target
        // than the narrow text field, which is easy to miss inside the pager.
        .onTapGesture { focused = field }
    }

    private func numberRow(_ field: Field, _ label: String, value: Binding<Double>, unit: String?) -> some View {
        row(field, label) {
            DecimalField(value: value, maxFractionDigits: 8, focus: $focused, field: field)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 90)
            if let unit {
                Text(unit).foregroundStyle(.secondary)
            }
        }
    }
}

/// A decimal text field driven by a raw string buffer rather than
/// `TextField(value:format:)`.
///
/// `TextField(value:format:)` reparses/reformats as you type, which discards a
/// just-typed decimal separator (you can never get past "1."). Here the text is
/// the source of truth while editing: the model updates whenever the text parses
/// to a number, and the text is only reformatted when the field is not focused
/// (e.g. on blur, or when the value changes externally such as a unit switch).
///
/// Parsing accepts both "," and "." as the decimal separator (inputs never carry
/// grouping separators), so it is robust regardless of what the decimal-pad key
/// produces versus the system "Number Format" setting.
private struct DecimalField<F: Hashable>: View {
    @Binding var value: Double
    var maxFractionDigits: Int
    var focus: FocusState<F?>.Binding
    let field: F

    @State private var text = ""

    var body: some View {
        TextField("", text: $text)
            .keyboardType(.decimalPad)
            .focused(focus, equals: field)
            .onChange(of: text) { _, newText in
                if let parsed = Self.parse(newText) { value = parsed }
            }
            .onChange(of: value) { _, newValue in
                if focus.wrappedValue != field { text = format(newValue) }
            }
            .onChange(of: focus.wrappedValue) { _, newFocus in
                if newFocus != field { text = format(value) } // normalise on blur
            }
            .onAppear { text = format(value) }
    }

    private func format(_ value: Double) -> String {
        SystemNumberStyle(minFractionDigits: 0, maxFractionDigits: maxFractionDigits, usesGrouping: false)
            .format(value)
    }

    private static func parse(_ string: String) -> Double? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil } // keep last value while cleared
        // Inputs never contain grouping separators, so normalise the decimal
        // separator to "." and parse locale-independently.
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }
}

/// The trailing pager page: a single button that adds a new vehicle.
private struct AddVehiclePage: View {
    let action: () -> Void

    var body: some View {
        VStack {
            Spacer()
            Button(action: action) {
                Label("Fahrzeug hinzufügen", systemImage: "plus.circle.fill")
                    .font(.title3.weight(.medium))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 28)
    }
}
