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
    
    @Published var useDefaultTextSize: Bool = GeneralSettings.textSizeOverride == nil {
        didSet {
            if useDefaultTextSize {
                GeneralSettings.textSizeOverride = nil
            } else {
                GeneralSettings.textSizeOverride = TextSize(rawValue: textSizeOverride)!.contentSizeCategory
            }
        }
    }
    
    @Published var textSizeOverride: Double = (TextSize.allCases.first(where: { $0.contentSizeCategory == GeneralSettings.textSizeOverride })?.rawValue ?? TextSize.medium.rawValue) {
        didSet {
            GeneralSettings.textSizeOverride = TextSize(rawValue: textSizeOverride)?.contentSizeCategory
        }
    }
}

enum TextSize: Double, CaseIterable {
    case extraSmall = 0
    case small = 1
    case medium = 2
    case large = 3
    case extraLarge = 4
    case extraExtraLarge = 5
    case extraExtraExtraLarge = 6
    
    var contentSizeCategory: UIContentSizeCategory {
        switch self {
        case .extraSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .extraLarge: return .extraLarge
        case .extraExtraLarge: return .extraExtraLarge
        case .extraExtraExtraLarge: return .extraExtraExtraLarge
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
    
    
    @State var textSize = TextSize.medium.rawValue

    var body: some View {
        SwiftUI.List {
            Section(header: HeaderText("Dark Mode", inset: inset)) {
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
            
            Section(header: HeaderText("Text Size", inset: inset)) {
                Button("Test") {
                    let preferred = UIFont.preferredFont(forTextStyle: .body).pointSize
                    UIApplication.shared.windows.first!.traitCollection
                    let metrics = UIFontMetrics(forTextStyle: .body)
                }
                Toggle(isOn: $settings.useDefaultTextSize) {
                    Text("Use System Size")
                }
                if !settings.useDefaultTextSize {
                    VStack(alignment: .center, spacing: 0) {
                        ZStack {
                            HStack {
                                Spacer()
                                ForEach(0...4, id: \.self) { _ in
                                    Rectangle()
                                        .foregroundColor(Color(.lightGray))
                                        .frame(width: 1, height: 8, alignment: .center)
                                    Spacer()
                                }
                            }
                            .padding(.horizontal, 2)
                            Slider(value: $settings.textSizeOverride, in: 0...6, step: 1) { changed in
                                guard !changed else { return }
                             NotificationCenter.default.post(name: UIContentSizeCategory.didChangeNotification, object: UIScreen.main, userInfo: [UIContentSizeCategory.newValueUserInfoKey: GeneralSettings.textSizeOverride!.rawValue])
//                                                                                                                                                     "UIContentSizeCategoryTextLegibilityEnabledKey": 0])
                                //AppDelegate.shared.tabBarController?.viewControllers = AppDelegate.shared.tabBarController?.getRootViewControllers()
                                //GeneralSettings.textSizeOverride = TextSize(rawValue: textSize)!.contentSizeCategory
                            }
                        }
                        HStack(alignment: .top) {
                            Text("A").font(.system(size: 11))
                            Spacer()
                            Text("A").font(.system(size: 26))
                        }
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
