import Foundation
import SwiftUI
import UIKit

struct AppIcon: View {
    @EnvironmentObject var hostingSplitView: HostingSettingsSplitView
    @State var selectedIconName = UIApplication.shared.alternateIconName

    var body: some View {
        SwiftUI.List {
            AppIconCellRow(alternateIconName: nil, name: "Default", selectedIconName: $selectedIconName)
            AppIconCellRow(alternateIconName: "Classic", name: "Classic", selectedIconName: $selectedIconName)
            AppIconCellRow(alternateIconName: "ClassicWhite", name: "Classic (White)", selectedIconName: $selectedIconName)
        }.possiblyInsetGroupedListStyle(inset: hostingSplitView.isSplit)
        .navigationBarTitle("App Icon")
    }
}

extension Notification.Name {
    static let appIconChanged = Notification.Name(rawValue: "appIconChanged")
}

struct AppIconCellRow: View {
    let alternateIconName: String?
    let name: String
    @Binding var selectedIconName: String?

    var body: some View {
        HStack {
            Image(uiImage: UIImage(imageLiteralResourceName: alternateIconName ?? "AppIcon_Default_80"))
                .resizable()
                .frame(width: 50, height: 50, alignment: .center)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.lightGray)))
            Text(name)
            Spacer()
            if selectedIconName == alternateIconName {
                Image(systemName: "checkmark").foregroundColor(Color(.systemBlue))
            }
        }.contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.setAlternateIconName(alternateIconName) { error in
                if let error = error {
                    UserEngagement.logError(error)
                } else {
                    selectedIconName = alternateIconName
                    NotificationCenter.default.post(name: .appIconChanged, object: nil)
                }
            }
        }
    }
}
