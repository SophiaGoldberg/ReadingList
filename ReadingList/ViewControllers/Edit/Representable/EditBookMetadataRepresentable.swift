import Foundation
import CoreData
import SwiftUI

struct EditBookMetadataRepresentable: UIViewControllerRepresentable {
    enum Configuration {
        case createFromMetadata(Book, NSManagedObjectContext)
        case create(BookReadState)
        case edit(NSManagedObjectID)
    }

    let config: Configuration

    func makeUIViewController(context: UIViewControllerRepresentableContext<EditBookMetadataRepresentable>) -> UINavigationController {
        return makeInnerViewController().inNavigationController()
    }

    private func makeInnerViewController() -> EditBookMetadata {
        switch config {
        case .createFromMetadata(let book, let context):
            return EditBookMetadata(bookToCreate: book, scratchpadContext: context)
        case .create(let readState):
            return EditBookMetadata(bookToCreateReadState: readState)
        case .edit(let id):
            return EditBookMetadata(bookToEditID: id)
        }
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: UIViewControllerRepresentableContext<EditBookMetadataRepresentable>) { }
}
