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

  var body: some Scene {
    MenuBarExtra("UserCommandServer", systemImage: "puzzlepiece.extension") {
      Text(appDisplayName)

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

            let ownBundleID = Bundle.main.bundleIdentifier
            let entries = WindowEnumerator.enumerateOtherAppWindows(excluding: ownBundleID)

            let view = WindowFramesView(entries: entries)
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
