import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        let level = UsageStyle.level(for: viewModel.currentUsage, isStale: viewModel.isStale)
        let color = UsageStyle.color(for: level)

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

            SparklineView(samples: viewModel.samples, color: color)
                .frame(height: 48)

            HStack {
                Text("Current CPU")
                Spacer()
                Text(viewModel.currentUsageText)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                    .monospacedDigit()
            }

            HStack {
                Text("Memory")
                Spacer()
                Text(viewModel.memoryUsageText)
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
        .frame(width: 280)
    }
}
