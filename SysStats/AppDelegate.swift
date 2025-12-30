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
                    // Helper installed, temperature will work now
                    SystemStats.shared.updateTemperatureAsync()
                }
            }
        }
    }

    // MARK: - Status Item Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: 170)

        if let button = statusItem?.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            button.action = #selector(togglePopover)
            button.target = self
            button.title = "C:—% G:—% R:—% —°"
        }
    }

    // MARK: - Stats Observation

    private func observeStatsManager() {
        StatsManager.shared.$currentMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.updateStatusText(with: metrics)
            }
            .store(in: &cancellables)
    }

    private func updateStatusText(with metrics: SystemMetrics) {
        statusItem?.button?.title = metrics.statusBarText
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 200)
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
