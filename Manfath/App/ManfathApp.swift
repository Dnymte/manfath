import SwiftUI

@main
struct ManfathApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // LSUIElement = YES means no dock icon and no default window.
        // A Settings scene gives SwiftUI something to initialize; the
        // real settings window lands in step 11.
        Settings { EmptyView() }
    }
}
