import Foundation
import CoreData
import SwiftUI

struct EditBookReadStateRepresentable: UIViewControllerRepresentable {
    let bookID: NSManagedObjectID

    func makeUIViewController(context: UIViewControllerRepresentableContext<EditBookReadStateRepresentable>) -> UINavigationController {
        return EditBookReadState(existingBookID: bookID).inNavigationController()
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: UIViewControllerRepresentableContext<EditBookReadStateRepresentable>) { }
}
