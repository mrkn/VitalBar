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
                Text("■")
                    .foregroundStyle(Color.blue.opacity(0.9))
                Text("App Memory")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.appMemoryText)
                    .monospacedDigit()
            }

            HStack(spacing: 4) {
                Text("■")
                    .foregroundStyle(Color.orange.opacity(0.9))
                Text("Wired Memory")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.wiredMemoryText)
                    .monospacedDigit()
            }

            HStack(spacing: 4) {
                Text("■")
                    .foregroundStyle(Color.teal.opacity(0.85))
                Text("Cached Files")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.cachedFilesText)
                    .monospacedDigit()
            }

            HStack(spacing: 4) {
                Text("■")
                    .hidden()
                Text("Compressed")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.compressedText)
                    .monospacedDigit()
            }

            HStack(spacing: 4) {
                Text("■")
                    .hidden()
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
