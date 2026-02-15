import SwiftUI

struct WindowFramesView: View {
  let payloadText: String

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
  let payload = """
  [
    { "bundle_identifier": "com.example.One", "x": 10, "y": 20, "width": 300, "height": 200 },
    { "bundle_identifier": "com.example.Two", "x": 40, "y": 60, "width": 640, "height": 480 }
  ]
  """
  return WindowFramesView(payloadText: payload)
}
