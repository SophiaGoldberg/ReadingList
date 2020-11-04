import Foundation
import CoreData
import os.log

public protocol ModelVersion: Equatable, CaseIterable {
    var modelName: String { get }
    static var modelBundle: Bundle { get }
    static var modelDirectoryName: String { get }
}

public extension ModelVersion {

    static var latest: Self {
        let lastItemIndex = Self.allCases.index(Self.allCases.startIndex, offsetBy: Self.allCases.count - 1)
        return Self.allCases[lastItemIndex]
    }

    var successor: Self? {
        let index = Self.allCases.firstIndex(of: self)!
        let nextIndex = Self.allCases.index(after: index)
        guard nextIndex != Self.allCases.endIndex else { return nil }
        return Self.allCases[nextIndex]
    }

    init?(storeURL: URL) throws {
        guard let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL, options: nil) else {
            return nil
        }

        #if DEBUG
            // Validation check - if multiple model versions match the store, we are in trouble.
            // Run this check in debug mode only as an optimisation.
            let matchingModels = Self.allCases.filter {
                $0.managedObjectModel().isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
            }
            if matchingModels.count > 1 {
                let modelNames = matchingModels.map { $0.modelName }.joined(separator: ",")
                assertionFailure("\(matchingModels.count) model versions matched the current store (\(modelNames)). Cannot guarantee that migrations will be performed correctly")
            }
        #endif

        // Reverse the model versions so the most recent is first; if the store is already
        // at the latest version, only one managed object model will need to be loaded.
        let version = Self.allCases.reversed().first {
            $0.managedObjectModel().isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }
        guard let result = version else {
            os_log("No managed object model compatible with store at %{public}s was found", type: .error, storeURL.absoluteString)
            throw MigrationError.incompatibleStore
        }
        self = result
    }

    func managedObjectModel() -> NSManagedObjectModel {
        guard let momURL = Self.modelBundle.url(forResource: modelName, withExtension: "mom", subdirectory: Self.modelDirectoryName) else {
            preconditionFailure("model version \(self) not found")
        }
        guard let model = NSManagedObjectModel(contentsOf: momURL) else { preconditionFailure("cannot open model at \(momURL)") }
        return model
    }

    func mappingModelToSuccessor() -> NSMappingModel? {
        guard let nextVersion = successor else { return nil }
        os_log("Loading specified mapping model used for step %{public}s to %{public}s", type: .info, modelName, nextVersion.modelName)
        guard let mapping = NSMappingModel(from: [Self.modelBundle], forSourceModel: managedObjectModel(), destinationModel: nextVersion.managedObjectModel()) else {
            // If there is no mapping model, build an inferred one
            os_log("No specified mapping model exists; creating inferred mapping model", type: .info)
            return try! NSMappingModel.inferredMappingModel(forSourceModel: managedObjectModel(), destinationModel: successor!.managedObjectModel())
        }
        return mapping
    }

    func migrationSteps(to version: Self) -> [MigrationStep] {
        guard self != version else { return [] }
        guard let mapping = mappingModelToSuccessor(), let nextVersion = successor else { preconditionFailure("Couldn't find mapping models") }
        let step = MigrationStep(source: managedObjectModel(), destination: nextVersion.managedObjectModel(), mapping: mapping)
        return [step] + nextVersion.migrationSteps(to: version)
    }
}

public final class MigrationStep {
    var source: NSManagedObjectModel
    var destination: NSManagedObjectModel
    var mapping: NSMappingModel

    init(source: NSManagedObjectModel, destination: NSManagedObjectModel, mapping: NSMappingModel) {
        self.source = source
        self.destination = destination
        self.mapping = mapping
    }
}

public enum MigrationError: Error {
    case incompatibleStore
}
