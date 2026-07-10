//
//  SettingsView.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import SwiftUI

struct SettingsView: View {
    @Bindable var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

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

    private var regenPercent: Binding<Double> {
        Binding(
            get: { locationManager.regenEfficiency * 100 },
            set: { locationManager.regenEfficiency = $0 / 100 }
        )
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

                Section("Fahrzeugparameter") {
                    HStack {
                        Text("Fahrzeugmasse")
                        Spacer()
                        TextField("kg", value: $locationManager.carMass, format: SystemNumberStyle(fractionDigits: 0))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .frame(width: 80)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Stirnfläche")
                        Spacer()
                        TextField("m²", value: $locationManager.frontalArea, format: SystemNumberStyle(fractionDigits: 1))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .frame(width: 80)
                        Text("m²")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Cw-Wert")
                        Spacer()
                        TextField("Cw", value: $locationManager.dragCoefficient, format: SystemNumberStyle(fractionDigits: 2))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .frame(width: 80)
                    }

                    HStack {
                        Text("Rollwiderstand")
                        Spacer()
                        TextField("Cr", value: $locationManager.rollingResistanceCoeff, format: SystemNumberStyle(fractionDigits: 3))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .frame(width: 80)
                    }

                    Toggle("Elektrofahrzeug", isOn: $locationManager.isElectric)

                    if locationManager.isElectric {
                        HStack {
                            Text("Rekuperationseffizienz")
                            Spacer()
                            TextField("%", value: regenPercent, format: SystemNumberStyle(fractionDigits: 0))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .monospacedDigit()
                                .frame(width: 80)
                            Text("%")
                                .foregroundStyle(.secondary)
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
        }
    }
}

/// A decimal format style backed by `NumberFormatter` so that it honors the
/// user's custom "Number Format" override in iOS Settings → Language & Region.
///
/// The modern `.number` `FormatStyle` derives its separators from the locale
/// identifier's data (e.g. `en_DE` → comma decimal) and ignores that override,
/// whereas `NumberFormatter` reads it from `Locale.autoupdatingCurrent` — the
/// same mechanism the system's own "Region Format Example" uses.
struct SystemNumberStyle: ParseableFormatStyle {
    /// Fixed number of fraction digits to display, matching the field's precision.
    var fractionDigits: Int

    func format(_ value: Double) -> String {
        Self.formatter(fractionDigits: fractionDigits).string(from: value as NSNumber) ?? ""
    }

    var parseStrategy: SystemNumberParseStrategy {
        SystemNumberParseStrategy(fractionDigits: fractionDigits)
    }

    /// Builds a decimal `NumberFormatter` bound to the live system locale.
    fileprivate static func formatter(fractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter
    }
}

struct SystemNumberParseStrategy: ParseStrategy {
    var fractionDigits: Int

    func parse(_ value: String) throws -> Double {
        // An empty field is treated as zero so the value can be cleared while editing.
        if value.trimmingCharacters(in: .whitespaces).isEmpty { return 0 }
        if let number = SystemNumberStyle.formatter(fractionDigits: fractionDigits).number(from: value) {
            return number.doubleValue
        }
        throw CocoaError(.formatting)
    }
}
