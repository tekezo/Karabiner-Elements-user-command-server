import AppKit
import ApplicationServices
import KarabinerElementsUserCommandReceiver
import SwiftUI

@main
struct UserCommandServerApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  private var appDisplayName: String {
    if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
      !name.isEmpty
    {
      return name
    }
    if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, !name.isEmpty
    {
      return name
    }
    return ProcessInfo.processInfo.processName
  }

  private func openMainWindow() {
    // Request to show the main window of the WindowGroup
    NSApp.activate(ignoringOtherApps: true)

    // If any existing window from our app is available, bring it to front
    for window in NSApp.windows {
      if let id = window.identifier, id.rawValue.contains("WindowGroup") {
        window.makeKeyAndOrderFront(nil)
        return
      }
    }

    // No existing WindowGroup window found; create one manually and show it
    let hosting = NSHostingController(
      rootView: ContentView()
    )
    let newWindow = NSWindow(contentViewController: hosting)
    newWindow.setContentSize(NSSize(width: 480, height: 320))
    newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    newWindow.title = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"
    newWindow.makeKeyAndOrderFront(nil)
  }

  var body: some Scene {
    MenuBarExtra("UserCommandServer", systemImage: "puzzlepiece.extension") {
      Text(appDisplayName)

      Divider()

      Button("Open Window") {
        openMainWindow()
      }

      Divider()

      Button("Quit") {
        NSApp.terminate(nil)
      }
    }

    // Define the main window scene, but don't auto-present it at launch
    WindowGroup {
      ContentView()
    }
    .defaultSize(width: 480, height: 320)
    .windowStyle(.titleBar)
    .windowResizability(.contentSize)
  }
}

class AppDelegate: NSObject, NSApplicationDelegate {
  var receiver: KEUserCommandReceiver?

  func applicationDidFinishLaunching(_ notification: Notification) {
    receiver = KEUserCommandReceiver(
      path: KEUserCommandReceiver.defaultSocketPath(),
      onJSON: { json in
        print("JSON:", json)

        // Expecting a dictionary-like payload
        guard let dict = json as? [String: Any] else { return }
        let command = dict["command"] as? String
        if command == "set_window_frames" {
          if let framesAny = dict["frames"] {
            do {
              // Convert loosely-typed payload into Data for Decodable
              let data = try JSONSerialization.data(withJSONObject: framesAny, options: [])
              let frames = try JSONDecoder().decode([WindowFrameSpec].self, from: data)
              DispatchQueue.main.async {
                WindowManager.setWindows(frames: frames)
              }
            } catch {
              print("Failed to decode frames:", error)
            }
          }
        } else if command == "show_window_frames" {
          DispatchQueue.main.async {
            // Open and pin our window to front
            NSApp.activate(ignoringOtherApps: true)

            // Try to bring existing WindowGroup window to front, otherwise create one
            var targetWindow: NSWindow?
            for window in NSApp.windows {
              if let id = window.identifier, id.rawValue.contains("WindowGroup") {
                targetWindow = window
                break
              }
            }

            if targetWindow == nil {
              let hosting = NSHostingController(rootView: ContentView())
              let newWindow = NSWindow(contentViewController: hosting)
              newWindow.setContentSize(NSSize(width: 640, height: 480))
              newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
              newWindow.title =
                Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"
              targetWindow = newWindow
            }

            guard let window = targetWindow else { return }

            window.setContentSize(NSSize(width: 600, height: 400))
            window.contentMinSize = NSSize(width: 600, height: 400)
            window.styleMask.insert(.resizable)

            // Make the window key and floating (always on top)
            window.makeKeyAndOrderFront(nil)
            window.level = .floating

            // Enumerate other app windows (exclude our own bundle id)
            let ownBundleID = Bundle.main.bundleIdentifier
            var entries: [(bundleID: String, frame: CGRect)] = []

            let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
            if let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
              as? [[String: AnyObject]]
            {
              for info in windowInfoList {
                guard let ownerName = info[kCGWindowOwnerName as String] as? String,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t
                else { continue }
                _ = ownerName

                // Resolve bundle identifier from PID
                var bundleID: String?
                if let app = NSRunningApplication(processIdentifier: pid) {
                  bundleID = app.bundleIdentifier
                }

                guard let bid = bundleID, bid != ownBundleID else { continue }

                let frame = CGRect(
                  x: boundsDict["X"] ?? 0,
                  y: boundsDict["Y"] ?? 0,
                  width: boundsDict["Width"] ?? 0,
                  height: boundsDict["Height"] ?? 0
                )

                // Skip zero-sized or hidden-like windows
                if frame.width <= 0 || frame.height <= 0 { continue }

                entries.append((bundleID: bid, frame: frame))
              }
            }

            // Sort by bundle identifier (dictionary order)
            entries.sort { $0.bundleID.localizedStandardCompare($1.bundleID) == .orderedAscending }

            // Build copyable text for set_window_frame payload
            var lines: [String] = []
            lines.append("# set_window_frame payload example:")
            lines.append("[")
            for (index, entry) in entries.enumerated() {
              let comma = index == entries.count - 1 ? "" : ","
              let f = entry.frame
              let line = String(
                format:
                  "  { \"bundle_identifier\": \"%@\", \"x\": %.0f, \"y\": %.0f, \"width\": %.0f, \"height\": %.0f }%@",
                entry.bundleID, f.origin.x, f.origin.y, f.size.width, f.size.height, comma
              )
              lines.append(line)
            }
            lines.append("]")
            let payloadText = lines.joined(separator: "\n")

            let view = WindowFramesView(payloadText: payloadText)
            if let hosting = window.contentViewController as? NSHostingController<WindowFramesView>
            {
              hosting.rootView = view
            } else {
              let hosting = NSHostingController(rootView: view)
              window.contentViewController = hosting
            }

            // Ensure visible and front
            window.makeKeyAndOrderFront(nil)
          }
        }
      },
      onError: { error in
        print("Error:", error)
      }
    )

    Task {
      do {
        try await receiver?.start()
        print("Listening:", KEUserCommandReceiver.defaultSocketPath())
      } catch {
        print("Start failed:", error)
      }
    }
  }
}
