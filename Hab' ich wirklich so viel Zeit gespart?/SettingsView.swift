//
//  SettingsView.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import SwiftUI

struct SettingsView: View {
    @Binding var threshold: Double
    @Binding var useMiles: Bool
    @Environment(\.dismiss) private var dismiss

    private var displayThreshold: Double {
        useMiles ? threshold / 1.60934 : threshold
    }

    private var sliderRange: ClosedRange<Double> {
        useMiles ? 48.2802...193.121 : 50...200 // 30-120 mph or 50-200 km/h
    }

    private var sliderStep: Double {
        useMiles ? 1.60934 : 5 // 1 mph steps or 5 km/h steps
    }

    private var speedUnit: String {
        useMiles ? "mph" : "km/h"
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
                    Slider(value: $threshold, in: sliderRange, step: sliderStep)
                } footer: {
                    Text("Zeitersparnis wird berechnet, wenn du schneller als \(Int(displayThreshold)) \(speedUnit) fährst.")
                }

                Section {
                    Picker("Einheit", selection: $useMiles) {
                        Text("mph").tag(true)
                        Text("km/h").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
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
