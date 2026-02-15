import AppKit
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
        // Expecting a dictionary-like payload
        guard let dict = json as? [String: Any] else { return }

        print("JSON:", dict)
        CommandHandler.handle(dict: dict)
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
