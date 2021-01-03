import UIKit

// Exists to launch our own subclass of UIApplication, rather than the default version which is
// launched by annotating the AppDelegate with @UIApplicationMain.
UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    NSStringFromClass(ReadingListApplication.self),
    NSStringFromClass(AppDelegate.self)
)
