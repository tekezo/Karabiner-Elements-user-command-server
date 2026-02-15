import AppKit
import ApplicationServices

enum WindowEnumerator {
  static func enumerateOtherAppWindows(excluding bundleID: String?) -> [(bundleID: String, frame: CGRect)] {
    var results: [(bundleID: String, frame: CGRect)] = []

    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: AnyObject]] else {
      return results
    }

    for info in windowInfoList {
      guard let _ = info[kCGWindowOwnerName as String] as? String,
            let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
            let pid = info[kCGWindowOwnerPID as String] as? pid_t else { continue }

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
}
