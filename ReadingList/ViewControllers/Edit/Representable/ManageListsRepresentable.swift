import Foundation
import SwiftUI

struct ManageListsRepresentable: UIViewControllerRepresentable {
    let book: Book
    let onComplete: (() -> Void)?

    func makeUIViewController(context: UIViewControllerRepresentableContext<ManageListsRepresentable>) -> UINavigationController {
        let rootAddToList = UIStoryboard.ManageLists.instantiateRoot(withStyle: .formSheet) as! UINavigationController
        let manageLists = rootAddToList.viewControllers[0] as! ManageLists
        manageLists.books = [book]
        manageLists.onComplete = onComplete
        return rootAddToList
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: UIViewControllerRepresentableContext<ManageListsRepresentable>) { }
}
