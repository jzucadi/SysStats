import SwiftUI

struct ContentView: View {
    @ObservedObject private var statsManager = StatsManager.shared
    @ObservedObject private var prefs = PreferencesManager.shared
    @State private var showingPreferences = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showingPreferences {
                preferencesView
            } else {
                statsView
            }
        }
        .frame(width: UIConstants.Popover.contentWidth)
    }

    // MARK: - Stats View

    private var statsView: some View {
        VStack(alignment: .leading, spacing: UIConstants.Layout.sectionSpacing) {
            HStack {
                Text("System Stats")
                    .font(.headline)
                Spacer()
                Button(action: { showingPreferences = true }) {
                    Image(systemName: "gear")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Preferences")
            }

            Divider()

            VStack(alignment: .leading, spacing: UIConstants.Layout.itemSpacing) {
                ForEach(StatType.allCases) { statType in
                    if statType.isEnabled(in: prefs) {
                        statRow(for: statType)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(statType.accessibilityLabel)
                            .accessibilityValue(statType.accessibilityValue(from: statsManager.currentMetrics, unit: prefs.temperatureUnit))
                    }
                }
            }

            Divider()

            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .accessibilityLabel("Quit SysStats")

                Spacer()

                Text("Updated every \(prefs.updateInterval.label)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func statRow(for statType: StatType) -> some View {
        let metrics = statsManager.currentMetrics

        if statType == .temperature {
            HStack {
                Image(systemName: statType.icon)
                    .frame(width: UIConstants.StatRow.iconWidth)
                    .foregroundColor(ColorUtilities.iconColor(for: statType))
                Text(statType.label)
                    .frame(width: UIConstants.StatRow.labelWidth, alignment: .leading)
                Spacer()
                Text(TemperatureUtilities.format(metrics.temperature, unit: prefs.temperatureUnit))
                    .monospacedDigit()
                    .foregroundColor(ColorUtilities.temperatureColor(for: metrics.temperature))
            }
        } else {
            StatRow(
                icon: statType.icon,
                label: statType.label,
                value: statType.formattedValue(from: metrics),
                percentage: statType.percentage(from: metrics)
            )
        }
    }

    // MARK: - Preferences View

    private var preferencesView: some View {
        VStack(alignment: .leading, spacing: UIConstants.Layout.sectionSpacing) {
            HStack {
                Button(action: { showingPreferences = false }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to Stats")

                Text("Preferences")
                    .font(.headline)

                Spacer()
            }

            Divider()

            // Update Interval
            VStack(alignment: .leading, spacing: UIConstants.Layout.preferenceItemSpacing) {
                Text("Update Interval")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Update Interval", selection: $prefs.updateInterval) {
                    ForEach(UpdateInterval.allCases, id: \.self) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Update Interval")
            }

            Divider()

            // Stats to Show
            VStack(alignment: .leading, spacing: UIConstants.Layout.preferenceItemSpacing) {
                Text("Show in Menu Bar")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Toggle("CPU Usage", isOn: $prefs.showCPU)
                    .toggleStyle(.checkbox)
                Toggle("GPU Usage", isOn: $prefs.showGPU)
                    .toggleStyle(.checkbox)
                Toggle("RAM Usage", isOn: $prefs.showRAM)
                    .toggleStyle(.checkbox)
                Toggle("Temperature", isOn: $prefs.showTemperature)
                    .toggleStyle(.checkbox)
            }

            Divider()

            // Temperature Unit
            VStack(alignment: .leading, spacing: UIConstants.Layout.preferenceItemSpacing) {
                Text("Temperature Unit")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Temperature Unit", selection: $prefs.temperatureUnit) {
                    ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Temperature Unit")
            }

            Divider()

            // Launch at Login
            Toggle("Launch at Login", isOn: $prefs.launchAtLogin)
                .toggleStyle(.checkbox)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Stat Row Component

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let percentage: Double

    var body: some View {
        HStack(spacing: UIConstants.StatRow.spacing) {
            Image(systemName: icon)
                .frame(width: UIConstants.StatRow.iconWidth)
                .foregroundColor(.accentColor)

            Text(label)
                .frame(width: UIConstants.StatRow.labelWidth, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: UIConstants.StatRow.barCornerRadius)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: UIConstants.StatRow.barHeight)

                    RoundedRectangle(cornerRadius: UIConstants.StatRow.barCornerRadius)
                        .fill(barColor)
                        .frame(width: geometry.size.width * UsageConstants.clampPercentage(percentage), height: UIConstants.StatRow.barHeight)
                }
            }
            .frame(height: UIConstants.StatRow.barHeight)

            Text(value)
                .monospacedDigit()
                .frame(width: UIConstants.StatRow.valueWidth, alignment: .trailing)
        }
    }

    private var barColor: Color {
        ColorUtilities.usageColor(for: percentage)
    }
}

#Preview {
    ContentView()
}
