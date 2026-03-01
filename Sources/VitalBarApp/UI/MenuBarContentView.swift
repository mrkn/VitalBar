import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    private static let legendMarkerSize: CGFloat = 7

    var body: some View {
        let cpuLevel = UsageStyle.level(for: viewModel.currentUsage, isStale: viewModel.isStale)
        let cpuColor = UsageStyle.color(for: cpuLevel)
        let memoryPressureColor = UsageStyle.color(for: viewModel.memoryPressureLevel)
        let cpuSocTemperatureText = MenuBarViewModel.cpuSoCTemperatureText(for: viewModel.temperatureReadings)
        let hasTemperatureReadings = !viewModel.temperatureReadings.isEmpty
        let shouldShowTemperatureDetails = MenuBarViewModel.shouldShowTemperatureDetails(for: viewModel.temperatureReadings)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("VitalBar")
                    .font(.headline)

                Spacer()

                if viewModel.isStale {
                    Label("Stale", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .labelStyle(.titleAndIcon)
                }
            }

            SparklineView(samples: viewModel.samples, color: cpuColor)
                .frame(height: 48)
                .padding(6)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
                }

            HStack {
                Text("Current CPU")
                Spacer()
                Text(viewModel.currentUsageText)
                    .fontWeight(.semibold)
                    .foregroundStyle(cpuColor)
                    .monospacedDigit()
            }

            if shouldShowTemperatureDetails {
                Menu {
                    ForEach(viewModel.temperatureReadings) { reading in
                        Text("\(reading.name): \(MenuBarViewModel.temperatureText(for: reading.celsius))")
                    }
                } label: {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
            } else if hasTemperatureReadings {
                HStack {
                    Text("Temperature")
                    Spacer()
                }
            } else {
                Button(action: {}) {
                    HStack {
                        Text("Temperature")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .disabled(true)
            }

            if let cpuSocTemperatureText {
                HStack {
                    Text("CPU / SoC")
                    Spacer()
                    Text(cpuSocTemperatureText)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
            }

            HStack {
                Text("Memory Used")
                Spacer()
                Text(viewModel.memoryUsageText)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }

            HStack {
                Text("Memory Pressure")
                Spacer()
                Text(viewModel.memoryPressureText)
                    .fontWeight(.semibold)
                    .foregroundStyle(memoryPressureColor)
                    .monospacedDigit()
            }

            HStack(spacing: 4) {
                legendMarker(Color.blue.opacity(0.9))
                Text("App Memory")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.appMemoryText)
                    .monospacedDigit()
            }

            HStack(spacing: 4) {
                legendMarker(Color.orange.opacity(0.9))
                Text("Wired Memory")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.wiredMemoryText)
                    .monospacedDigit()
            }

            HStack(spacing: 4) {
                legendMarker(Color.teal.opacity(0.85))
                Text("Cached Files")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.cachedFilesText)
                    .monospacedDigit()
            }

            HStack(spacing: 4) {
                legendMarker(.clear)
                Text("Compressed")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.compressedText)
                    .monospacedDigit()
            }

            HStack(spacing: 4) {
                legendMarker(.clear)
                Text("Swap Used")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.swapUsedText)
                    .monospacedDigit()
            }

            HStack {
                Text("Disk Usage")
                Spacer()
                Text(viewModel.diskUsageText)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }

            HStack {
                Text("Uptime")
                Spacer()
                Text(viewModel.uptimeText)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }

            if let staleMessage = viewModel.staleMessage, viewModel.isStale {
                Text(staleMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Divider()

            Button("Quit VitalBar") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
        .padding(12)
        .frame(width: 300)
    }

    private func legendMarker(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: Self.legendMarkerSize, height: Self.legendMarkerSize)
            .accessibilityHidden(true)
    }
}
