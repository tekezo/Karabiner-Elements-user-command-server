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
        if command == "set_window_frame" {
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
