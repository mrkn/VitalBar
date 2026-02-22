import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        let cpuLevel = UsageStyle.level(for: viewModel.currentUsage, isStale: viewModel.isStale)
        let cpuColor = UsageStyle.color(for: cpuLevel)
        let memoryPressureColor = UsageStyle.color(for: viewModel.memoryPressureLevel)

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

            HStack {
                Text("Current CPU")
                Spacer()
                Text(viewModel.currentUsageText)
                    .fontWeight(.semibold)
                    .foregroundStyle(cpuColor)
                    .monospacedDigit()
            }

            HStack {
                Text("Memory Used")
                Spacer()

                HStack(spacing: 8) {
                    Text(viewModel.memoryUsageText)
                    Text("(\(viewModel.memoryUsagePercentText))")
                        .foregroundStyle(.secondary)
                }
                .fontWeight(.semibold)
                .monospacedDigit()
            }

            HStack {
                Text("App Memory")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.appMemoryText)
                    .monospacedDigit()
            }

            HStack {
                Text("Wired Memory")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.wiredMemoryText)
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

            HStack {
                Text("Cached Files")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.cachedFilesText)
                    .monospacedDigit()
            }

            HStack {
                Text("Compressed")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.compressedText)
                    .monospacedDigit()
            }

            HStack {
                Text("Swap Used")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.swapUsedText)
                    .monospacedDigit()
            }

            HStack {
                Text("Uptime")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.uptimeText)
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
}
