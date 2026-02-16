import AppKit
import Combine
import SwiftUI

@MainActor
final class WindowFramesStore: ObservableObject {
  static let shared = WindowFramesStore()

  @Published var entries: [(bundleID: String, frame: CGRect)] = []
}

struct WindowFramesView: View {
  @ObservedObject private var store = WindowFramesStore.shared

  private var payloadText: String {
    var lines: [String] = []
    lines.append("# set_window_frames payload example:")
    lines.append("[")
    var seen: Set<String> = []
    var payloadItems: [String] = []
    for entry in store.entries {
      if entry.bundleID == "com.apple.controlcenter" {
        continue
      }

      let f = entry.frame
      let item = String(
        format:
          "  { \"bundle_identifier\": \"%@\", \"x\": %.0f, \"y\": %.0f, \"width\": %.0f, \"height\": %.0f }",
        entry.bundleID, f.origin.x, f.origin.y, f.size.width, f.size.height
      )
      if seen.insert(item).inserted {
        payloadItems.append(item)
      }
    }

    for (index, item) in payloadItems.enumerated() {
      let comma = index == payloadItems.count - 1 ? "" : ","
      lines.append("\(item)\(comma)")
    }
    lines.append("]")
    return lines.joined(separator: "\n")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("set_window_frames payload example")
        .font(.headline)
        .padding()

      ScrollView {
        Text(payloadText)
          .font(.system(.body, design: .monospaced))
          .textSelection(.enabled)
          .padding()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(nsColor: .textBackgroundColor))
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
      )
    }
    .frame(minWidth: 600, minHeight: 200)
  }
}

#Preview {
  let sample: [(bundleID: String, frame: CGRect)] = [
    ("com.example.One", CGRect(x: 10, y: 20, width: 300, height: 200)),
    ("com.example.Two", CGRect(x: 40, y: 60, width: 640, height: 480)),
  ]
  WindowFramesStore.shared.entries = sample
  return WindowFramesView()
}
