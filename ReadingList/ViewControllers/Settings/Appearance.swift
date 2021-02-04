import Foundation
import SwiftUI

class AppearanceSettings: ObservableObject {
    @Published var showExpandedDescription: Bool = GeneralSettings.showExpandedDescription {
        didSet {
            GeneralSettings.showExpandedDescription = showExpandedDescription
        }
    }

    @Published var showAmazonLinks: Bool = GeneralSettings.showAmazonLinks {
        didSet {
            GeneralSettings.showAmazonLinks = showAmazonLinks
        }
    }

    @Published var darkModeOverride: Bool? = GeneralSettings.darkModeOverride {
        didSet {
            GeneralSettings.darkModeOverride = darkModeOverride
        }
    }
}

struct Appearance: View {
    @EnvironmentObject var hostingSplitView: HostingSettingsSplitView
    @ObservedObject var settings = AppearanceSettings()

    var inset: Bool {
        hostingSplitView.isSplit
    }

    func updateWindowInterfaceStyle() {
        if let darkModeOverride = settings.darkModeOverride {
            AppDelegate.shared.window?.overrideUserInterfaceStyle = darkModeOverride ? .dark : .light
        } else {
            AppDelegate.shared.window?.overrideUserInterfaceStyle = .unspecified
        }
    }

    var darkModeSystemSettingToggle: Binding<Bool> {
        Binding(
            get: { settings.darkModeOverride == nil },
            set: {
                settings.darkModeOverride = $0 ? nil : false
                updateWindowInterfaceStyle()
            }
        )
    }

    var body: some View {
        SwiftUI.List {
            Section(
                header: HeaderText("Dark Mode", inset: inset)
            ) {
                Toggle(isOn: darkModeSystemSettingToggle) {
                    Text("Use System Setting")
                }
                if let darkModeOverride = settings.darkModeOverride {
                    CheckmarkCellRow("Light Appearance", checkmark: !darkModeOverride)
                        .onTapGesture {
                            settings.darkModeOverride = false
                            updateWindowInterfaceStyle()
                        }
                    CheckmarkCellRow("Dark Appearance", checkmark: darkModeOverride)
                        .onTapGesture {
                            settings.darkModeOverride = true
                            updateWindowInterfaceStyle()
                        }
                }
            }

            Section(
                header: HeaderText("Book Details", inset: inset),
                footer: FooterText("Enable Expanded Descriptions to automatically show each book's full description.", inset: inset)
            ) {
                Toggle(isOn: $settings.showAmazonLinks) {
                    Text("Show Amazon Links")
                }
                Toggle(isOn: $settings.showExpandedDescription) {
                    Text("Expanded Descriptions")
                }
            }
        }.possiblyInsetGroupedListStyle(inset: inset)
        .navigationBarTitle("Appearance")
    }
}

struct CheckmarkCellRow: View {
    let text: String
    let checkmark: Bool

    init(_ text: String, checkmark: Bool) {
        self.text = text
        self.checkmark = checkmark
    }

    var body: some View {
        HStack {
            Text(text)
            Spacer()
            if checkmark {
                Image(systemName: "checkmark").foregroundColor(Color(.systemBlue))
            }
        }.contentShape(Rectangle())
    }
}

struct Appearance_Previews: PreviewProvider {
    static var previews: some View {
        Appearance().environmentObject(HostingSettingsSplitView())
    }
}
