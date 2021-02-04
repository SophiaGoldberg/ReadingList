import Foundation
import SwiftUI

class PrivacySettings: ObservableObject {
    @Published var sendCrashReports = UserEngagement.sendCrashReports {
        didSet { UserEngagement.sendCrashReports = sendCrashReports }
    }

    @Published var sendAnalytics = UserEngagement.sendAnalytics {
        didSet { UserEngagement.sendAnalytics = sendAnalytics }
    }
}

struct Privacy: View {
    @EnvironmentObject var hostingSplitView: HostingSettingsSplitView
    @ObservedObject var settings = PrivacySettings()
    @State var crashReportsAlertDisplated = false
    @State var analyticsAlertDisplayed = false

    var inset: Bool {
        hostingSplitView.isSplit
    }

    var body: some View {
        SwiftUI.List {
            Section(
                header: HeaderText("Privacy Policy", inset: inset)
            ) {
                NavigationLink(destination: PrivacyPolicy()) {
                    Text("View Privacy Policy")
                }
            }
            Section(
                header: HeaderText("Reporting", inset: inset),
                footer: FooterText("""
                Crash reports can be automatically sent to help me detect and fix issues. Analytics can \
                be used to help gather usage statistics for different features. This never includes any \
                details of your books.\
                \(BuildInfo.thisBuild.type != .testFlight ? "" : " If Beta testing, these cannot be disabled.")
                """, inset: inset)) {

                Toggle(isOn: Binding(get: { settings.sendCrashReports }, set: { newValue in
                    if !newValue {
                        crashReportsAlertDisplated = true
                    } else {
                        settings.sendCrashReports = true
                        UserEngagement.logEvent(.enableCrashReports)
                    }
                })) {
                    Text("Send Crash Reports")
                }.alert(isPresented: $crashReportsAlertDisplated) {
                    crashReportsAlert
                }

                Toggle(isOn: Binding(get: { settings.sendAnalytics }, set: { newValue in
                    if !newValue {
                        analyticsAlertDisplayed = true
                    } else {
                        settings.sendAnalytics = true
                        UserEngagement.logEvent(.enableAnalytics)
                    }
                })) {
                    Text("Send Analytics")
                }.alert(isPresented: $analyticsAlertDisplayed) {
                    analyticsAlert
                }
            }
        }.possiblyInsetGroupedListStyle(inset: inset)
        .navigationBarTitle("Privacy")
    }

    var crashReportsAlert: Alert {
        Alert(
            title: Text("Turn Off Crash Reports?"),
            message: Text("""
            Anonymous crash reports alert me if this app crashes, to help me fix bugs. \
            This never includes any information about your books. Are you \
            sure you want to turn this off?
            """),
            primaryButton: .default(Text("Leave On")) {
                settings.sendCrashReports = true
            },
            secondaryButton: .destructive(Text("Turn Off")) {
                settings.sendCrashReports = false
                UserEngagement.logEvent(.disableCrashReports)
            }
        )
    }

    var analyticsAlert: Alert {
        Alert(
            title: Text("Turn Off Analytics?"),
            message: Text("""
            Anonymous usage statistics help prioritise development. This never includes \
            any information about your books. Are you sure you want to turn this off?
            """),
            primaryButton: .default(Text("Leave On")) {
                settings.sendAnalytics = true
            },
            secondaryButton: .destructive(Text("Turn Off")) {
                settings.sendAnalytics = false
                UserEngagement.logEvent(.disableAnalytics)
            }
        )
    }
}
