import SwiftUI

struct WindowFramesView: View {
  let entries: [(bundleID: String, frame: CGRect)]

  private var payloadText: String {
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
    return lines.joined(separator: "\n")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("set_window_frame payload example")
        .font(.headline)

      ScrollView {
        Text(payloadText)
          .font(.system(.body, design: .monospaced))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(8)
          .background(.thinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }

      HStack {
        Spacer()
        Button("Copy Payload") {
          let pb = NSPasteboard.general
          pb.clearContents()
          pb.setString(payloadText, forType: .string)
        }
      }
    }
    .padding()
    .frame(minWidth: 600, minHeight: 400)
  }
}

#Preview {
  let sample: [(bundleID: String, frame: CGRect)] = [
    ("com.example.One", CGRect(x: 10, y: 20, width: 300, height: 200)),
    ("com.example.Two", CGRect(x: 40, y: 60, width: 640, height: 480)),
  ]
  return WindowFramesView(entries: sample)
}
