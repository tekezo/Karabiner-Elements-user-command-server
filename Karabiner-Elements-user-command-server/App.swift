import AppKit
import KarabinerElementsUserCommandReceiver
import SwiftUI

@main
struct UserCommandServerApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  private let version =
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

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
    MenuBarExtra(
      content: {
        Text("\(appDisplayName) \(version)")

        Divider()

        Button("Quit") {
          NSApp.terminate(nil)
        }
      },
      label: {
        Label(
          title: { Text(appDisplayName) },
          icon: {
            // To prevent the menu icon from appearing blurry, it is necessary to explicitly set the displayScale.
            Image(systemName: "puzzlepiece.extension")
              .environment(\.displayScale, 2.0)
          }
        )
      }
    )
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
