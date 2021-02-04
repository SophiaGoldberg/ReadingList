import Foundation
import CoreData
import SwiftUI

struct EditBookNotesRepresentable: UIViewControllerRepresentable {
    let bookID: NSManagedObjectID

    func makeUIViewController(context: UIViewControllerRepresentableContext<EditBookNotesRepresentable>) -> UINavigationController {
        return EditBookNotes(existingBookID: bookID).inNavigationController()
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: UIViewControllerRepresentableContext<EditBookNotesRepresentable>) { }
}
