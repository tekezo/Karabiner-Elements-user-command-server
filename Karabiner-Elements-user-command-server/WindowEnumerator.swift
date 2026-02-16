import AppKit
import ApplicationServices

enum WindowEnumerator {
  static func enumerateOtherAppWindows(excluding bundleID: String?) -> [(
    bundleID: String, frame: CGRect
  )] {
    var results: [(bundleID: String, frame: CGRect)] = []
    var bundleIDByPID: [pid_t: String?] = [:]

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

      // Resolve bundle identifier from PID only once per process.
      let bid: String?
      if let cached = bundleIDByPID[pid] {
        bid = cached
      } else {
        let resolved = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        bundleIDByPID[pid] = resolved
        bid = resolved
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
