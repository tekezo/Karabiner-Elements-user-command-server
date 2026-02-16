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
      NSApp.activate(ignoringOtherApps: true)

      //
      // Update WindowFramesStore.shared.entries
      //

      let ownBundleID = Bundle.main.bundleIdentifier

      WindowFramesStore.shared.entries =
        WindowEnumerator.enumerateOtherAppWindows(excluding: ownBundleID)

      //
      // Create new window if needed
      //

      if framesWindow == nil {
        let window = NSWindow(
          contentViewController: NSHostingController(rootView: WindowFramesView()))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"
        window.identifier = NSUserInterfaceItemIdentifier("WindowFrames")
        window.level = .floating
        window.setContentSize(NSSize(width: 900, height: 400))
        window.minSize = NSSize(width: 600, height: 200)
        window.center()
        window.makeKeyAndOrderFront(nil)

        framesWindow = window

        NotificationCenter.default.addObserver(
          forName: NSWindow.willCloseNotification,
          object: window,
          queue: .main
        ) { _ in
          Task { @MainActor in
            framesWindow = nil
          }
        }
      }
    }
  }
}
