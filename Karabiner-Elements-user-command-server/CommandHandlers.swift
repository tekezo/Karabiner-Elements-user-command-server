import AppKit
import Foundation
import SwiftUI

struct CommandHandler {
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
