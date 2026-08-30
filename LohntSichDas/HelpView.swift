//
//  HelpView.swift
//  Hab' ich wirklich so viel Zeit gespart?
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(spacing: 4) {
                        Text(L("helpTitle"))
                            .font(.largeTitle.bold())
                        Text(L("helpSubtitleOr"))
                        Text(L("helpSubtitleFull"))
                            .font(.title2)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                    section(
                        icon: "speedometer",
                        title: L("helpSpeed"),
                        text: L("helpSpeedText")
                    )

                    section(
                        icon: "bolt.fill",
                        title: L("helpPower"),
                        text: L("helpPowerText")
                    )

                    section(
                        icon: "clock.arrow.circlepath",
                        title: L("helpTimeSaved"),
                        text: L("helpTimeSavedText")
                    )

                    section(
                        icon: "fuelpump",
                        title: L("helpExtraConsumption"),
                        text: L("helpExtraConsumptionText")
                    )

                    section(
                        icon: "timer",
                        title: L("helpTravelTime"),
                        text: L("helpTravelTimeText")
                    )

                    section(
                        icon: "road.lanes",
                        title: L("helpDistance"),
                        text: L("helpDistanceText")
                    )

                    section(
                        icon: "gauge.with.dots.needle.50percent",
                        title: L("helpAverageSpeed"),
                        text: L("helpAverageSpeedText")
                    )

                    section(
                        icon: "car.fill",
                        title: L("helpTrafficJam"),
                        text: L("helpTrafficJamText")
                    )

                    section(
                        icon: "stop.fill",
                        title: L("helpStop"),
                        text: L("helpStopText")
                    )

                    section(
                        icon: "car.2.fill",
                        title: L("helpVehicles"),
                        text: L("helpVehiclesText")
                    )

                    section(
                        icon: "gearshape",
                        title: L("helpSettings"),
                        text: L("helpSettingsText")
                    )

                    section(
                        icon: "location.fill",
                        title: L("helpBackground"),
                        text: L("helpBackgroundText")
                    )
                }
                .padding(24)
            }
            .navigationTitle(L("help"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func section(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
