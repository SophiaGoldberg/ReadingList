import CoreData

/**
 An object which is a delegate of an `NSFetchedResultsController`, but forwards the events to another object, one which conforms to
 `ResultsControllerDelegateForwarderReceiver`. Exists as Objective-C limitations mean that a generic class cannot be
 a `NSFetchedResultsControllerDelegate`. Instead, a generic class can hold an instance of ths object, and forward the events to itself.
 */
class ResultsControllerDelegateForwarder: NSObject, NSFetchedResultsControllerDelegate {
    weak var forwardTo: ResultsControllerDelegateForwarderReceiver?

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        forwardTo?.controllerWillChangeContent(controller)
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        forwardTo?.controllerDidChangeContent(controller)
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        forwardTo?.controller(controller, didChange: anObject, at: indexPath, for: type, newIndexPath: newIndexPath)
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        forwardTo?.controller(controller, didChange: sectionInfo, atSectionIndex: sectionIndex, for: type)
    }
}

/**
 A class which can receive events forwarded from an `NSFetchedResultsControllerDelegate`. The defined functions have identifcal signatures;
 this protocol exists only so that a `ResultsControllerDelegateForwarder` can forward the delegate events to _any_ class, including
 a class with generic arguments, which is not possible otherwise.
 */
protocol ResultsControllerDelegateForwarderReceiver: class {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?)

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType)

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
}
