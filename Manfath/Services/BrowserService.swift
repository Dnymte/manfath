import AppKit
import Foundation

public enum BrowserService {
    /// Opens the given URL in the user's default browser.
    /// Returns false if the URL is malformed or no handler exists.
    @discardableResult
    public static func open(url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }

    /// Convenience for the common case of `http://localhost:<port>`.
    @discardableResult
    public static func openLocalhost(port: UInt16) -> Bool {
        guard let url = URL(string: "http://localhost:\(port)") else { return false }
        return open(url: url)
    }

    /// Reveal a filesystem path in Finder, selecting the item.
    public static func revealInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
