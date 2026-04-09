//
//  ContentView.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import SwiftUI

struct ContentView: View {
    @State private var locationManager = LocationManager()
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title2)
                }
                .padding(.trailing, 24)
                .padding(.top, 8)
            }
            Spacer()

            // Speed display
            VStack(spacing: 4) {
                Text("\(Int(locationManager.currentSpeed))")
                    .font(.system(size: 140, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("km/h")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Referenz: \(Int(locationManager.threshold)) km/h")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Time saved display
            VStack(spacing: 8) {
                Text("Gesparte Zeit")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(formattedTimeSaved)
                    .font(.system(size: 52, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(formattedPercentage)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer()

            // Travel time and average speed
            HStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("Fahrzeit")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(formattedTravelTime)
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                VStack(spacing: 8) {
                    Text("Durchschnitt")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("\(Int(locationManager.averageSpeed)) km/h")
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }

            Spacer()

            // Reset button
            Button {
                locationManager.reset()
            } label: {
                Text("Reset")
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.red, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            locationManager.start()
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(threshold: $locationManager.threshold)
        }
    }

    private var formattedPercentage: String {
        guard locationManager.travelTime > 0 else { return "0.0 %" }
        let pct = (locationManager.timeSaved / locationManager.travelTime) * 100
        return String(format: "%.1f %%", pct)
    }

    private var formattedTravelTime: String {
        let total = Int(locationManager.travelTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var formattedTimeSaved: String {
        let total = locationManager.timeSaved
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        let seconds = Int(total) % 60
        let millis = Int((total.truncatingRemainder(dividingBy: 1)) * 1000)
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%03d", hours, minutes, seconds, millis)
        }
        return String(format: "%d:%02d.%03d", minutes, seconds, millis)
    }
}

#Preview {
    ContentView()
}
