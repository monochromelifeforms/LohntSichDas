//
//  SettingsView.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import SwiftUI

struct SettingsView: View {
    @Binding var threshold: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Referenzgeschwindigkeit")
                        Spacer()
                        Text("\(Int(threshold)) km/h")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $threshold, in: 80...200, step: 5)
                } footer: {
                    Text("Zeitersparnis wird berechnet, wenn du schneller als \(Int(threshold)) km/h fährst.")
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
