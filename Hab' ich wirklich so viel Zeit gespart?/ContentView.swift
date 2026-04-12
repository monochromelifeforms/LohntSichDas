//
//  ContentView.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import SwiftUI

struct ContentView: View {
    @State private var locationManager = LocationManager()
    @State private var showSettings = false
    @State private var showHelp = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    showHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.title2)
                }
                .padding(.leading, 24)
                .padding(.top, 8)
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

            // Travel time, distance, and average speed
            HStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Fahrzeit")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(formattedTravelTime)
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                VStack(spacing: 8) {
                    Text("Strecke")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(formattedDistance)
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                VStack(spacing: 8) {
                    Text("Durchschnitt")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("\(Int(locationManager.averageSpeed)) km/h")
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }

            Spacer()

            // Staumodus and Stop buttons
            HStack(spacing: 12) {
                Button {
                    locationManager.trafficJamMode.toggle()
                } label: {
                    Label("Staumodus", systemImage: locationManager.trafficJamMode ? "car.fill" : "car")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(locationManager.trafficJamMode ? .orange : .gray.opacity(0.3),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(locationManager.trafficJamMode ? .white : .primary)
                }

                Button {
                    locationManager.stopDriving()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(locationManager.isDriving ? .blue : .gray.opacity(0.3),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(locationManager.isDriving ? .white : .primary)
                }
                .disabled(!locationManager.isDriving)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

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
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
    }

    private var formattedPercentage: String {
        guard locationManager.travelTime > 0 else { return "0.00 %" }
        let pct = (locationManager.timeSaved / locationManager.travelTime) * 100
        return String(format: "%.2f %%", pct)
    }

    private var formattedDistance: String {
        let km = locationManager.totalDistance / 1000
        if km >= 100 {
            return String(format: "%.0f km", km)
        }
        return String(format: "%.1f km", km)
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
