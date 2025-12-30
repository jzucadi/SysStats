import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var updateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        startUpdateTimer()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: 170)

        if let button = statusItem?.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            button.action = #selector(togglePopover)
            button.target = self
            updateStatusText()
        }
    }

    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateStatusText()
        }
    }

    private func updateStatusText() {
        let cpuUsage = Int(SystemStats.shared.getCPUUsage())
        let ramUsage = Int(SystemStats.shared.getRAMUsage())
        // Placeholder values for now
        let gpuUsage = Int.random(in: 5...80)
        let temperature = Int.random(in: 40...75)

        let statusText = String(format: "C:%d%% G:%d%% R:%d%% %d°", cpuUsage, gpuUsage, ramUsage, temperature)

        DispatchQueue.main.async {
            self.statusItem?.button?.title = statusText
        }
    }

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
