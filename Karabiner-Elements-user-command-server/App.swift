import ApplicationServices
import KarabinerElementsUserCommandReceiver
import SwiftUI

@main
struct UserCommandServerApp: App {
  let receiver: KEUserCommandReceiver

  init() {
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
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .task {
          do {
            try await receiver.start()
            print("Listening:", KEUserCommandReceiver.defaultSocketPath())
          } catch {
            print("Start failed:", error)
          }
        }
    }
  }
}
