import Foundation
import SwiftUI
import WhatsNewKit

struct ChangeListWrapper: UIViewControllerRepresentable {
    typealias UIViewControllerType = WhatsNewViewController
    let changeListProvider = ChangeListProvider()

    func makeUIViewController(context: Context) -> WhatsNewViewController {
        return changeListProvider.thisVersionChangeList()!
    }

    func updateUIViewController(_ uiViewController: WhatsNewViewController, context: Context) { }
}
