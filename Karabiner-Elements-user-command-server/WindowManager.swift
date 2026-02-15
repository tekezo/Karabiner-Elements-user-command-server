import ApplicationServices
import Cocoa

struct WindowFrameSpec: Decodable {
  let bundleIdentifier: String
  let x: XValue
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat

  private enum CodingKeys: String, CodingKey {
    case bundleIdentifier = "bundle_identifier"
    case x, y, width, height
  }

  enum XValue: Decodable {
    case number(CGFloat)
    case center

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let str = try? container.decode(String.self), str.lowercased() == "center" {
        self = .center
        return
      }
      if let num = try? container.decode(CGFloat.self) {
        self = .number(num)
        return
      }
      throw DecodingError.typeMismatch(
        CGFloat.self,
        .init(codingPath: decoder.codingPath, debugDescription: "x must be a number or 'center'"))
    }
  }
}

enum WindowManager {
  // Ensure the app has Accessibility permissions
  @MainActor static func ensureAccessibilityPermissions() -> Bool {
    let options: CFDictionary = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
  }

  @MainActor static func setWindows(frames: [WindowFrameSpec]) {
    _ = ensureAccessibilityPermissions()
    for spec in frames {
      setWindow(for: spec)
    }
  }

  @MainActor private static func setWindow(for spec: WindowFrameSpec) {
    guard
      let app = NSRunningApplication.runningApplications(
        withBundleIdentifier: spec.bundleIdentifier
      ).first
    else {
      print("WindowManager: app not running:", spec.bundleIdentifier)
      return
    }

    let appElem = AXUIElementCreateApplication(app.processIdentifier)

    var value: AnyObject?
    let result: AXError = AXUIElementCopyAttributeValue(
      appElem, kAXWindowsAttribute as CFString, &value)
    guard result == AXError.success, let windows = value as? [AXUIElement],
      let window = windows.first
    else {
      print("WindowManager: no accessible windows for:", spec.bundleIdentifier)
      return
    }

    // Compute target origin
    var originX: CGFloat
    switch spec.x {
    case .number(let x):
      originX = x
    case .center:
      // Center on main screen horizontally
      let screen = NSScreen.main
      let screenFrame = screen?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
      originX = screenFrame.midX - (spec.width / 2.0)
    }
    let originY = spec.y

    let size = CGSize(width: spec.width, height: spec.height)
    let position = CGPoint(x: originX, y: originY)

    // macOS uses a bottom-left origin for AX frames in global coordinates
    setAXSize(window: window, size: size)
    setAXPosition(window: window, position: position)
  }

  @MainActor @discardableResult
  private static func setAXPosition(window: AXUIElement, position: CGPoint) -> Bool {
    var pos = position
    if let axPos = AXValueCreate(.cgPoint, &pos) {
      let result: AXError = AXUIElementSetAttributeValue(
        window, kAXPositionAttribute as CFString, axPos)
      if result != AXError.success {
        print("WindowManager: failed to set position, err=", result.rawValue)
        return false
      }
      return true
    } else {
      print("WindowManager: failed to create AX position value")
      return false
    }
  }

  @MainActor @discardableResult
  private static func setAXSize(window: AXUIElement, size: CGSize) -> Bool {
    var sz = size
    if let axSize = AXValueCreate(.cgSize, &sz) {
      let result: AXError = AXUIElementSetAttributeValue(
        window, kAXSizeAttribute as CFString, axSize)
      if result != AXError.success {
        print("WindowManager: failed to set size, err=", result.rawValue)
        return false
      }
      return true
    } else {
      print("WindowManager: failed to create AX size value")
      return false
    }
  }
}
