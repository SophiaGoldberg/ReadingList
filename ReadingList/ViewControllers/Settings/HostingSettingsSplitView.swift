import Foundation
import Combine

enum SettingsSelection {
    case about
    case general
    case appearance
    case appIcon
    case tip
    case importExport
    case backup
    case privacy
}

class HostingSettingsSplitView: ObservableObject, HostingSplitView {
    @Published var isSplit = false
    @Published var selectedCell: SettingsSelection?
}
