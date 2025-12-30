import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        installHelperIfNeeded()
        observeStatsManager()
        observePreferences()
        PreferencesManager.shared.checkLaunchAtLoginStatus()
        StatsManager.shared.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        StatsManager.shared.stopMonitoring()
    }

    // MARK: - Helper Installation

    private func installHelperIfNeeded() {
        if HelperManager.shared.needsInstallation {
            HelperManager.shared.installHelper { success in
                if success {
                    SystemStats.shared.updateTemperatureAsync()
                }
            }
        }
    }

    // MARK: - Status Item Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            button.action = #selector(togglePopover)
            button.target = self
            button.title = "SysStats"
        }
    }

    // MARK: - Stats Observation

    @MainActor private func observeStatsManager() {
        StatsManager.shared.$currentMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.updateStatusText(with: metrics)
            }
            .store(in: &cancellables)
    }

    private func observePreferences() {
        let prefs = PreferencesManager.shared

        Publishers.CombineLatest4(
            prefs.$showCPU,
            prefs.$showGPU,
            prefs.$showRAM,
            prefs.$showTemperature
        )
        .combineLatest(prefs.$temperatureUnit)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusText(with: StatsManager.shared.currentMetrics)
            }
        }
        .store(in: &cancellables)
    }

    private func updateStatusText(with metrics: SystemMetrics) {
        statusItem?.button?.title = metrics.statusBarText(prefs: PreferencesManager.shared)
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 320)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: ContentView())
    }

    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
