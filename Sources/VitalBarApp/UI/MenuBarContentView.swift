import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    private static let legendMarkerSize: CGFloat = 7
    private static let primaryMenuWidth: CGFloat = 300
    private static let submenuWidth: CGFloat = 190
    private static let submenuCloseDelayNanoseconds: UInt64 = 180_000_000
    private static let menuHorizontalPadding: CGFloat = 6
    private static let menuVerticalPadding: CGFloat = 12
    private static let menuRowHorizontalPadding: CGFloat = 8
    private static let appMenuRowVerticalPadding: CGFloat = 6
    @State private var isAppMenuPresented = false
    @State private var isPointerOverAppMenuTrigger = false
    @State private var isPointerOverAppSubmenu = false
    @State private var appMenuCloseTask: Task<Void, Never>?

    var body: some View {
        let cpuLevel = UsageStyle.level(for: viewModel.currentUsage, isStale: viewModel.isStale)
        let cpuColor = UsageStyle.color(for: cpuLevel)
        let memoryPressureColor = UsageStyle.color(for: viewModel.memoryPressureLevel)
        let cpuSocTemperatureText = MenuBarViewModel.cpuSoCTemperatureText(for: viewModel.temperatureReadings)
        let hasTemperatureReadings = !viewModel.temperatureReadings.isEmpty
        let shouldShowTemperatureDetails = MenuBarViewModel.shouldShowTemperatureDetails(for: viewModel.temperatureReadings)

        VStack(alignment: .leading, spacing: 10) {
            appMenuRow {
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

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onHover { isHovering in
                    isPointerOverAppMenuTrigger = isHovering
                    updateAppMenuPresentation()
                }
                .background {
                    SubmenuWindowPresenter(
                        isPresented: $isAppMenuPresented,
                        horizontalOffset: 2,
                        onHoverChanged: { isHovering in
                            isPointerOverAppSubmenu = isHovering
                            updateAppMenuPresentation()
                        }
                    ) {
                        appSubmenu
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isAppMenuPresented ? Color.accentColor.opacity(0.2) : .clear)
            }

            SparklineView(samples: viewModel.samples, color: cpuColor)
                .frame(height: 48)
                .padding(6)
                .padding(.horizontal, Self.menuRowHorizontalPadding)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
                }

            menuRow {
                HStack {
                    Text("Current CPU")
                    Spacer()
                    Text(viewModel.currentUsageText)
                        .fontWeight(.semibold)
                        .foregroundStyle(cpuColor)
                        .monospacedDigit()
                }
            }

            if shouldShowTemperatureDetails {
                Menu {
                    ForEach(viewModel.temperatureReadings) { reading in
                        Text("\(reading.name): \(MenuBarViewModel.temperatureText(for: reading.celsius))")
                    }
                } label: {
                    menuRow {
                        HStack {
                            Text("Temperature")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
            } else if hasTemperatureReadings {
                menuRow {
                    HStack {
                        Text("Temperature")
                        Spacer()
                    }
                }
            } else {
                Button(action: {}) {
                    menuRow {
                        HStack {
                            Text("Temperature")
                            Spacer()
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(true)
            }

            if let cpuSocTemperatureText {
                menuRow {
                    HStack {
                        Text("CPU / SoC")
                        Spacer()
                        Text(cpuSocTemperatureText)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.secondary)
                }
            }

            menuRow {
                HStack {
                    Text("Memory Used")
                    Spacer()
                    Text(viewModel.memoryUsageText)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }

            menuRow {
                HStack {
                    Text("Memory Pressure")
                    Spacer()
                    Text(viewModel.memoryPressureText)
                        .fontWeight(.semibold)
                        .foregroundStyle(memoryPressureColor)
                        .monospacedDigit()
                }
            }

            menuRow {
                HStack(spacing: 4) {
                    legendMarker(Color.blue.opacity(0.9))
                    Text("App Memory")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.appMemoryText)
                        .monospacedDigit()
                }
            }

            menuRow {
                HStack(spacing: 4) {
                    legendMarker(Color.orange.opacity(0.9))
                    Text("Wired Memory")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.wiredMemoryText)
                        .monospacedDigit()
                }
            }

            menuRow {
                HStack(spacing: 4) {
                    legendMarker(Color.teal.opacity(0.85))
                    Text("Cached Files")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.cachedFilesText)
                        .monospacedDigit()
                }
            }

            menuRow {
                HStack(spacing: 4) {
                    legendMarker(.clear)
                    Text("Compressed")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.compressedText)
                        .monospacedDigit()
                }
            }

            menuRow {
                HStack(spacing: 4) {
                    legendMarker(.clear)
                    Text("Swap Used")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.swapUsedText)
                        .monospacedDigit()
                }
            }

            menuRow {
                HStack {
                    Text("Disk Usage")
                    Spacer()
                    Text(viewModel.diskUsageText)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }

            menuRow {
                HStack {
                    Text("Uptime")
                    Spacer()
                    Text(viewModel.uptimeText)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }

            if let staleMessage = viewModel.staleMessage, viewModel.isStale {
                menuRow {
                    Text(staleMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, Self.menuHorizontalPadding)
        .padding(.vertical, Self.menuVerticalPadding)
        .frame(width: Self.primaryMenuWidth)
        .onDisappear {
            appMenuCloseTask?.cancel()
            isAppMenuPresented = false
            isPointerOverAppMenuTrigger = false
            isPointerOverAppSubmenu = false
        }
    }

    private func legendMarker(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: Self.legendMarkerSize, height: Self.legendMarkerSize)
            .accessibilityHidden(true)
    }

    private func menuRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, Self.menuRowHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func appMenuRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        menuRow {
            content()
                .padding(.vertical, Self.appMenuRowVerticalPadding)
        }
    }

    private var appSubmenu: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { viewModel.launchAtLoginEnabled },
                    set: { viewModel.setLaunchAtLoginEnabled($0) }
                )
            )
            .toggleStyle(.checkbox)

            Divider()

            Button("Quit VitalBar") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])

            if let launchAtLoginMessage = viewModel.launchAtLoginMessage {
                Divider()

                Text(launchAtLoginMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(width: Self.submenuWidth, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }

    private func updateAppMenuPresentation() {
        if isPointerOverAppMenuTrigger || isPointerOverAppSubmenu {
            appMenuCloseTask?.cancel()
            appMenuCloseTask = nil
            isAppMenuPresented = true
            return
        }

        appMenuCloseTask?.cancel()
        appMenuCloseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.submenuCloseDelayNanoseconds)
            guard !Task.isCancelled else {
                return
            }

            if !isPointerOverAppMenuTrigger && !isPointerOverAppSubmenu {
                isAppMenuPresented = false
            }
        }
    }
}
