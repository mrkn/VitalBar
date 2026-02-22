import SwiftUI
import VitalBarCore

@main
struct VitalBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel: MenuBarViewModel
    @AppStorage("menuBarLabelRenderer") private var menuBarLabelRendererRawValue = MenuBarLabelRenderer.vector.rawValue

    init() {
        let loadSampler = CPULoadSampler()
        let historyService = CPUHistoryService(
            sampler: loadSampler,
            historyCapacity: CPUHistoryService.defaultHistoryCapacity,
            sampleInterval: CPUHistoryService.defaultSampleInterval,
            staleAfter: CPUHistoryService.defaultStaleAfter
        )

        _viewModel = StateObject(wrappedValue: MenuBarViewModel(service: historyService))
    }

    private var menuBarLabelRenderer: MenuBarLabelRenderer {
        MenuBarLabelRenderer(rawValue: menuBarLabelRendererRawValue) ?? .vector
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel)
        } label: {
            MenuBarLabelView(
                cpuSamples: viewModel.samples,
                memorySamples: viewModel.memoryHistory,
                diskSamples: viewModel.diskUsageHistory,
                isStale: viewModel.isStale,
                renderer: menuBarLabelRenderer
            )
        }
        .menuBarExtraStyle(.window)
    }
}
