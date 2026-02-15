import AppKit
import ApplicationServices

enum WindowEnumerator {
  static func enumerateOtherAppWindows(excluding bundleID: String?) -> [(
    bundleID: String, frame: CGRect
  )] {
    var results: [(bundleID: String, frame: CGRect)] = []

    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard
      let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
        as? [[String: AnyObject]]
    else {
      return results
    }

    for info in windowInfoList {
      guard info[kCGWindowOwnerName as String] is String,
        let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
        let pid = info[kCGWindowOwnerPID as String] as? pid_t
      else { continue }

      // Resolve bundle identifier from PID
      var bid: String?
      if let app = NSRunningApplication(processIdentifier: pid) {
        bid = app.bundleIdentifier
      }

      guard let bundle = bid, bundle != bundleID else { continue }

      let frame = CGRect(
        x: boundsDict["X"] ?? 0,
        y: boundsDict["Y"] ?? 0,
        width: boundsDict["Width"] ?? 0,
        height: boundsDict["Height"] ?? 0
      )

      if frame.width <= 0 || frame.height <= 0 { continue }

      results.append((bundleID: bundle, frame: frame))
    }

    // Sort by bundle identifier for stable ordering
    results.sort { $0.bundleID.localizedStandardCompare($1.bundleID) == .orderedAscending }
    return results
  }

  // Apply frames to all windows of given bundle identifiers using Accessibility API
  static func applyFramesToAllWindows(specs: [WindowFrameSpec]) {
    for spec in specs {
      applyFrameToAllWindows(
        bundleID: spec.bundleIdentifier,
        frame: CGRect(
          x: toCGFloat(spec.x),
          y: toCGFloat(spec.y),
          width: toCGFloat(spec.width),
          height: toCGFloat(spec.height)
        )
      )
    }
  }

  // Safely convert various numeric-like values to CGFloat without requiring BinaryInteger
  private static func toCGFloat<T>(_ value: T) -> CGFloat {
    // Fast paths for common numeric types
    if let v = value as? CGFloat { return v }
    if let v = value as? Double { return CGFloat(v) }
    if let v = value as? Float { return CGFloat(v) }

    if let v = value as? Int { return CGFloat(v) }
    if let v = value as? Int8 { return CGFloat(v) }
    if let v = value as? Int16 { return CGFloat(v) }
    if let v = value as? Int32 { return CGFloat(v) }
    if let v = value as? Int64 { return CGFloat(v) }

    if let v = value as? UInt { return CGFloat(v) }
    if let v = value as? UInt8 { return CGFloat(v) }
    if let v = value as? UInt16 { return CGFloat(v) }
    if let v = value as? UInt32 { return CGFloat(v) }
    if let v = value as? UInt64 { return CGFloat(v) }

    // Fallback: try NSNumber and String conversions
    if let num = value as? NSNumber { return CGFloat(truncating: num) }
    if let str = value as? String, let d = Double(str) { return CGFloat(d) }

    // As a last resort, return 0 to avoid crashing; caller can decide how to handle it
    return 0
  }

  private static func applyFrameToAllWindows(bundleID: String, frame: CGRect) {
    // Find running apps matching bundleID
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    for app in runningApps {
      let pid = app.processIdentifier
      let appElement = AXUIElementCreateApplication(pid)

      // Get windows array
      var value: CFTypeRef?
      let result = AXUIElementCopyAttributeValue(
        appElement, kAXWindowsAttribute as CFString, &value)
      guard result == .success, let windows = value as? [AXUIElement] else { continue }

      for window in windows {
        // Optionally skip minimized or hidden windows
        if isWindowHidden(window) { continue }

        // Get current size to skip zero-sized windows
        var sizeRef: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)

        var currentSize: CGSize = .zero
        if let s = sizeRef, CFGetTypeID(s) == AXValueGetTypeID() {
          // Bind to AXValue without force-casting by bridging through Unmanaged
          let axValue: AXValue = unsafeDowncast(s, to: AXValue.self)
          if AXValueGetType(axValue) == .cgSize {
            AXValueGetValue(axValue, .cgSize, &currentSize)
          }
        }
        if currentSize.width <= 0 || currentSize.height <= 0 { continue }

        // Set position
        var newOrigin = CGPoint(x: frame.origin.x, y: frame.origin.y)
        let posValue = AXValueCreate(.cgPoint, &newOrigin)
        if let posValue {
          AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        }

        // Set size
        var newSize = CGSize(width: frame.width, height: frame.height)
        let sizeValue = AXValueCreate(.cgSize, &newSize)
        if let sizeValue {
          AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
      }
    }
  }

  private static func isWindowHidden(_ window: AXUIElement) -> Bool {
    var hiddenRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(window, kAXHiddenAttribute as CFString, &hiddenRef)
      == .success,
      let hidden = hiddenRef as? Bool, hidden
    {
      return true
    }

    // Minimized check
    var miniRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &miniRef)
      == .success,
      let minimized = miniRef as? Bool, minimized
    {
      return true
    }

    return false
  }
}
