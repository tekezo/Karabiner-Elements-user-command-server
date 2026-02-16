import AppKit
import Foundation
import SwiftUI

struct CommandHandler {
  @MainActor private static var framesWindow: NSWindow?

  nonisolated static func handle(dict: [String: Any]) {
    let command = dict["command"] as? String
    if command == "set_window_frames" {
      handleSetWindowFrames(dict: dict)
    } else if command == "show_window_frames" {
      handleShowWindowFrames()
    }
  }

  nonisolated private static func handleSetWindowFrames(dict: [String: Any]) {
    guard let framesAny = dict["frames"] else { return }

    do {
      // Convert loosely-typed payload into Data for Decodable
      let data = try JSONSerialization.data(withJSONObject: framesAny, options: [])
      let frames = try JSONDecoder().decode([WindowFrameSpec].self, from: data)
      Task { @MainActor in
        WindowManager.setWindows(frames: frames)
      }
    } catch {
      print("Failed to decode frames:", error)
    }
  }

  nonisolated private static func handleShowWindowFrames() {
    Task { @MainActor in
      // Open and pin our window to front
      NSApp.activate(ignoringOtherApps: true)

      let window: NSWindow
      if let existing = framesWindow {
        window = existing
      } else {
        let hosting = NSHostingController(rootView: ContentView())
        let newWindow = NSWindow(contentViewController: hosting)
        newWindow.setContentSize(NSSize(width: 900, height: 400))
        newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        newWindow.title =
          Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"
        newWindow.identifier = NSUserInterfaceItemIdentifier("WindowFrames")
        framesWindow = newWindow
        NotificationCenter.default.addObserver(
          forName: NSWindow.willCloseNotification,
          object: newWindow,
          queue: .main
        ) { _ in
          Task { @MainActor in
            framesWindow = nil
          }
        }
        window = newWindow
      }

      window.setContentSize(NSSize(width: 900, height: 400))
      window.contentMinSize = NSSize(width: 900, height: 400)
      window.styleMask.insert(.resizable)

      // Make the window key and floating (always on top)
      window.makeKeyAndOrderFront(nil)
      window.level = .floating

      let ownBundleID = Bundle.main.bundleIdentifier
      let entries = WindowEnumerator.enumerateOtherAppWindows(excluding: ownBundleID)

      let view = WindowFramesView(entries: entries)
      if let hosting = window.contentViewController as? NSHostingController<WindowFramesView> {
        hosting.rootView = view
      } else {
        let hosting = NSHostingController(rootView: view)
        window.contentViewController = hosting
      }

      // Ensure visible and front
      window.makeKeyAndOrderFront(nil)
    }
  }
}
