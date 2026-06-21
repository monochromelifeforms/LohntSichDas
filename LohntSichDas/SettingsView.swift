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
                        Text("\(Int(locationManager.carMass)) kg")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $locationManager.carMass, in: 800...3000, step: 50)

                    HStack {
                        Text("Stirnfläche")
                        Spacer()
                        Text(String(format: "%.1f m²", locationManager.frontalArea))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $locationManager.frontalArea, in: 1.5...3.5, step: 0.1)

                    HStack {
                        Text("Cw-Wert")
                        Spacer()
                        Text(String(format: "%.2f", locationManager.dragCoefficient))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $locationManager.dragCoefficient, in: 0.20...0.50, step: 0.01)

                    HStack {
                        Text("Rollwiderstand")
                        Spacer()
                        Text(String(format: "%.3f", locationManager.rollingResistanceCoeff))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $locationManager.rollingResistanceCoeff, in: 0.008...0.020, step: 0.001)

                    HStack {
                        Text("Antriebsstrang-Wirkungsgrad")
                        Spacer()
                        Text("\(Int(locationManager.drivetrainEfficiency * 100)) %")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $locationManager.drivetrainEfficiency, in: 0.70...0.98, step: 0.01)
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
