import SwiftUI

struct Settings: View {
    static let appStoreAddress = "itunes.apple.com/gb/app/reading-list-book-tracker/id1217139955"
    static let feedbackEmailAddress = "feedback@readinglist.app"
    let writeReviewUrl = URL(string: "itms-apps://\(Settings.appStoreAddress)?action=write-review")!

    @EnvironmentObject var hostingSplitView: HostingSettingsSplitView
    @State var badgeOnBackupRow = AutoBackupManager.shared.cannotRunScheduledAutoBackups

    func background(_ row: SettingsSelection) -> some View {
        if row != hostingSplitView.selectedCell { return Color.clear }
        return Color(.systemGray4)
    }

    var backgroundColor: some View {
        Color(.systemGroupedBackground)
            .edgesIgnoringSafeArea([.leading, .trailing])
    }

    var header: some View {
        HStack {
            Spacer()
            if #available(iOS 14.0, *) {
                SettingsHeader().textCase(nil)
            } else {
                SettingsHeader()
            }
            Spacer()
        }.padding(.vertical, 20)
    }

    var body: some View {
        SwiftUI.List {
            Section(header: header) {

                SettingsCell(.about, title: "About", imageName: "info", color: .blue)
                IconCell("Rate", imageName: "star.fill", backgroundColor: .orange)
                    .onTapGesture {
                        UIApplication.shared.open(writeReviewUrl, options: [:])
                    }
                    .foregroundColor(Color(.label))
                SettingsCell(.tip, title: "Leave Tip", imageName: "heart.fill", color: .pink)
            }
            Section {
                SettingsCell(.general, title: "General", imageName: "gear", color: .gray)
                SettingsCell(.appearance, title: "Appearance", imageName: "textformat.size", color: Color(.systemIndigo))
                if UIApplication.shared.supportsAlternateIcons {
                    SettingsCell(.appIcon, title: "App Icon", image: CurrentIconImage()
                    )
                }
                SettingsCell(.importExport, title: "Import & Export", imageName: "doc.fill", color: .green)
                SettingsCell(.backup, title: "Backup & Restore", imageName: "icloud.fill", color: .icloudBlue, badge: badgeOnBackupRow)
                    .onReceive(NotificationCenter.default.publisher(for: .autoBackupEnabledOrDisabled)) { _ in
                        badgeOnBackupRow = AutoBackupManager.shared.cannotRunScheduledAutoBackups
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.backgroundRefreshStatusDidChangeNotification)) { _ in
                        badgeOnBackupRow = AutoBackupManager.shared.cannotRunScheduledAutoBackups
                    }
                SettingsCell(.privacy, title: "Privacy", imageName: "lock.fill", color: Color(.darkGray))
            }
        }.listStyle(GroupedListStyle())
        .navigationBarTitle("Settings")
    }
}

struct CurrentIconImage: View {
    @State var currentIconName = UIApplication.shared.alternateIconName

    var body: some View {
        Image("AppIcon_\(currentIconName ?? "Default")_29")
                .cornerRadius(8)
            .onReceive(NotificationCenter.default.publisher(for: .appIconChanged)) { _ in
            currentIconName = UIApplication.shared.alternateIconName
            }
    }
}

extension Color {
    static let icloudBlue = Color(
        .sRGB,
        red: 62 / 255,
        green: 149 / 255,
        blue: 236 / 255,
        opacity: 1
    )
}

struct SettingsHeader: View {
    var version: String {
        "v\(BuildInfo.thisBuild.version)"
    }

    @State var isShowingDebugMenu = false
    @State var iconName = UIApplication.shared.alternateIconName

    var imageName: String {
        guard let iconName = iconName else { return "AppIcon_Default_80" }
        if iconName == "Classic" {
            return "AppIcon_ClassicWhite_80"
        } else {
            return "AppIcon_\(iconName)_80"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(imageName)
                .cornerRadius(18)
                .onLongPressGesture {
                    #if DEBUG
                    isShowingDebugMenu = true
                    #endif
                }.sheet(isPresented: $isShowingDebugMenu) {
                    #if DEBUG
                    DebugSettings(isPresented: $isShowingDebugMenu)
                    #else
                    EmptyView()
                    #endif
                }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text("Reading List")
                        .fontWeight(.semibold)
                        .font(.callout)
                    Text(version).font(.footnote)
                }.foregroundColor(Color(.label))
                Text("by Andrew Bennet")
                    .font(.footnote)
            }
        }.onReceive(NotificationCenter.default.publisher(for: .appIconChanged)) { _ in
            iconName = UIApplication.shared.alternateIconName
        }
    }
}

struct SettingsCell<T>: View where T: View {
    @EnvironmentObject var hostingSplitView: HostingSettingsSplitView
    var isSelected: Bool {
        hostingSplitView.selectedCell == cell
    }

    var selectedColor: Color {
        if hostingSplitView.isSplit {
            return Color(UIColor(named: "SplitViewCellSelection")!)
        } else {
            return .clear
        }
    }

    var cellBackground: Color {
        isSelected ? selectedColor : Color.clear
    }

    var cellLabelColor: Color {
        isSelected && hostingSplitView.isSplit ? .white : Color(.label)
    }

    let cell: SettingsSelection
    let title: String
    let image: T
    let badge: Bool

    init(_ cell: SettingsSelection, title: String, image: T, badge: Bool = false) {
        self.cell = cell
        self.title = title
        self.image = image
        self.badge = badge
    }

    init(_ cell: SettingsSelection, title: String, imageName: String, color: Color, badge: Bool = false) where T == SystemSettingsIcon {
        self.cell = cell
        self.title = title
        self.image = SystemSettingsIcon(systemImageName: imageName, backgroundColor: color)
        self.badge = badge
    }

    var body: some View {
        IconCell(
            title,
            image: image,
            withChevron: !hostingSplitView.isSplit,
            withBadge: badge ? "1" : nil,
            textForegroundColor: cellLabelColor
        )
        .onTapGesture {
            hostingSplitView.selectedCell = cell
        }
        .listRowBackground(cellBackground.edgesIgnoringSafeArea([.horizontal]))
    }
}

struct Settings_Previews: PreviewProvider {
    static var previews: some View {
        Settings().environmentObject(HostingSettingsSplitView())
    }
}
