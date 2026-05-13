import ApplicationServices
import Cocoa

struct WindowFrameSpec: Decodable {
  let bundleIdentifier: String
  let x: XValue
  let y: YValue
  let width: CGFloat
  let height: CGFloat

  private enum CodingKeys: String, CodingKey {
    case bundleIdentifier = "bundle_identifier"
    case x, y, width, height
  }

  enum XValue: Decodable {
    case number(CGFloat)
    case left
    case center
    case right

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let str = try? container.decode(String.self) {
        switch str.lowercased() {
        case "left":
          self = .left
          return
        case "center":
          self = .center
          return
        case "right":
          self = .right
          return
        default:
          break
        }
      }
      if let num = try? container.decode(CGFloat.self) {
        self = .number(num)
        return
      }
      throw DecodingError.typeMismatch(
        CGFloat.self,
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "x must be a number, 'left', 'center', or 'right'"))
    }
  }

  enum YValue: Decodable {
    case number(CGFloat)
    case top
    case center
    case bottom

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let str = try? container.decode(String.self) {
        switch str.lowercased() {
        case "top":
          self = .top
          return
        case "center":
          self = .center
          return
        case "bottom":
          self = .bottom
          return
        default:
          break
        }
      }
      if let num = try? container.decode(CGFloat.self) {
        self = .number(num)
        return
      }
      throw DecodingError.typeMismatch(
        CGFloat.self,
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "y must be a number, 'top', 'center', or 'bottom'"))
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
    guard result == AXError.success, let windows = value as? [AXUIElement] else {
      print("WindowManager: no accessible windows for:", spec.bundleIdentifier)
      return
    }

    // Compute target origin (shared for all windows)
    let screen = NSScreen.main
    let screenFrame = screen?.frame ?? NSScreen.screens.first?.frame ?? .zero
    let visibleScreenFrame = screen?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
    var originX: CGFloat
    switch spec.x {
    case .number(let x):
      originX = x
    case .left:
      originX = visibleScreenFrame.minX
    case .center:
      originX = screenFrame.midX - (spec.width / 2.0)
    case .right:
      originX = visibleScreenFrame.maxX - spec.width
    }
    var originY: CGFloat
    switch spec.y {
    case .number(let y):
      originY = y
    case .top:
      originY = screenFrame.maxY - visibleScreenFrame.maxY
    case .center:
      originY = screenFrame.midY - (spec.height / 2.0)
    case .bottom:
      originY = screenFrame.maxY - visibleScreenFrame.minY - spec.height
    }

    let size = CGSize(width: spec.width, height: spec.height)
    let position = CGPoint(x: originX, y: originY)

    for window in windows {
      // Skip hidden or minimized windows
      var hiddenRef: CFTypeRef?
      if AXUIElementCopyAttributeValue(window, kAXHiddenAttribute as CFString, &hiddenRef)
        == .success,
        let hidden = hiddenRef as? Bool, hidden
      {
        continue
      }
      var miniRef: CFTypeRef?
      if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &miniRef)
        == .success,
        let minimized = miniRef as? Bool, minimized
      {
        continue
      }

      // Skip desktop elements by role
      var roleRef: CFTypeRef?
      if AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleRef) == .success,
        let role = roleRef as? String, role == "AXDesktop"
      {
        continue
      }

      // Skip zero-sized windows
      var sizeRef: CFTypeRef?
      _ = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)
      var currentSize: CGSize = .zero
      if let s = sizeRef, CFGetTypeID(s) == AXValueGetTypeID() {
        let axValue: AXValue = unsafeDowncast(s, to: AXValue.self)
        if AXValueGetType(axValue) == .cgSize {
          AXValueGetValue(axValue, .cgSize, &currentSize)
        }
      }
      if currentSize.width <= 0 || currentSize.height <= 0 { continue }

      // Apply position and size.
      // If the window's original position is near the right edge of screen,
      // increasing its width during resizing may fail, so the position needs to be changed first.
      _ = setAXPosition(window: window, position: position)
      _ = setAXSize(window: window, size: size)
    }
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
