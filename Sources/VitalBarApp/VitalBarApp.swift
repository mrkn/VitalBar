import SwiftUI
import VitalBarCore

@main
struct VitalBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel: MenuBarViewModel

    init() {
        let loadSampler = CPULoadSampler()
        let historyService = CPUHistoryService(
            sampler: loadSampler,
            temperatureSampler: SMCTemperatureSampler(),
            historyCapacity: CPUHistoryService.defaultHistoryCapacity,
            sampleInterval: CPUHistoryService.defaultSampleInterval,
            staleAfter: CPUHistoryService.defaultStaleAfter
        )

        let viewModel = MenuBarViewModel(service: historyService)
        _viewModel = StateObject(wrappedValue: viewModel)
        AppTerminationCoordinator.shared.register {
            await viewModel.shutdown()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(
                viewModel: viewModel,
                appSubmenuController: appDelegate.appSubmenuController
            )
        } label: {
            MenuBarLabelView(
                cpuSamples: viewModel.samples,
                memorySamples: viewModel.memoryHistory,
                diskSamples: viewModel.diskUsageHistory,
                isStale: viewModel.isStale,
                keepMacAwakeEnabled: viewModel.preventSleepEnabled
            )
            .id(viewModel.preventSleepEnabled)
        }
        .menuBarExtraStyle(.window)
    }
}
